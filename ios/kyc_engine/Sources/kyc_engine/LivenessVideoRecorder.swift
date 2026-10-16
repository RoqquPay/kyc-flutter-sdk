import AVFoundation
import VideoToolbox

struct LivenessVideoError: LocalizedError {
  let errorDescription: String?

  init(_ message: String) {
    errorDescription = message
  }
}

final class LivenessVideoRecorder {
  private let width: Int
  private let height: Int
  private let rotation: Int
  private let maxDuration: CMTime
  private let session: VTCompressionSession
  private let encodeQueue = DispatchQueue(label: "kyc_engine.video.encode")
  private let stateQueue = DispatchQueue(label: "kyc_engine.video.state")
  private var samples: [CMSampleBuffer] = []
  private var forceKeyFrame = false
  private var released = false

  init(width: Int, height: Int, rotation: Int, fps: Int, bitrate: Int, maxDurationUs: Int64) throws {
    self.width = width
    self.height = height
    self.rotation = rotation
    maxDuration = CMTime(value: maxDurationUs, timescale: 1_000_000)

    let attributes: [CFString: Any] = [
      kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey: width,
      kCVPixelBufferHeightKey: height,
    ]
    var created: VTCompressionSession?
    let status = VTCompressionSessionCreate(
      allocator: nil,
      width: Int32(width),
      height: Int32(height),
      codecType: kCMVideoCodecType_H264,
      encoderSpecification: nil,
      imageBufferAttributes: attributes as CFDictionary,
      compressedDataAllocator: nil,
      outputCallback: nil,
      refcon: nil,
      compressionSessionOut: &created
    )
    guard status == noErr, let created else {
      throw LivenessVideoError("Could not create the video encoder (\(status))")
    }
    session = created

    VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
    VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
    VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
    VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)
    VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: fps as CFNumber)
    VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 1 as CFNumber)
    VTCompressionSessionPrepareToEncodeFrames(session)
  }

  func encode(_ bgra: Data, bytesPerRow: Int, timestampUs: Int64, completion: @escaping (Error?) -> Void) {
    encodeQueue.async { [self] in
      guard !released else { return completion(nil) }
      do {
        try encodeFrame(bgra, bytesPerRow: bytesPerRow, timestampUs: timestampUs)
        completion(nil)
      } catch {
        completion(error)
      }
    }
  }

  func finish(path: String) throws -> Bool {
    let active: Bool = encodeQueue.sync {
      guard !released else { return false }
      VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
      return true
    }
    guard active else { return false }

    let snapshot: [CMSampleBuffer] = stateQueue.sync {
      let copy = samples
      samples.removeAll()
      forceKeyFrame = true
      return copy
    }
    guard let last = snapshot.last else { return false }
    let newest = CMSampleBufferGetPresentationTimeStamp(last)
    guard
      let start = snapshot.firstIndex(where: {
        isKeyFrame($0) && CMTimeSubtract(newest, CMSampleBufferGetPresentationTimeStamp($0)) <= maxDuration
      })
    else { return false }

    try write(Array(snapshot[start...]), to: URL(fileURLWithPath: path))
    return true
  }

  func release() {
    encodeQueue.async { [self] in
      released = true
      VTCompressionSessionInvalidate(session)
    }
  }

  private func encodeFrame(_ bgra: Data, bytesPerRow sourceStride: Int, timestampUs: Int64) throws {
    guard bgra.count >= sourceStride * height else {
      throw LivenessVideoError("Frame is smaller than expected")
    }
    guard let pool = VTCompressionSessionGetPixelBufferPool(session) else {
      throw LivenessVideoError("Video encoder has no pixel buffer pool")
    }
    var pixelBuffer: CVPixelBuffer?
    let poolStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
    guard poolStatus == kCVReturnSuccess, let pixelBuffer else {
      throw LivenessVideoError("Could not allocate a pixel buffer (\(poolStatus))")
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if let destination = CVPixelBufferGetBaseAddress(pixelBuffer) {
      let destinationStride = CVPixelBufferGetBytesPerRow(pixelBuffer)
      let rowBytes = min(width * 4, sourceStride, destinationStride)
      bgra.withUnsafeBytes { raw in
        guard let source = raw.baseAddress else { return }
        for row in 0..<height {
          memcpy(destination + row * destinationStride, source + row * sourceStride, rowBytes)
        }
      }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

    let properties: CFDictionary? =
      takeForceKeyFrame() ? [kVTEncodeFrameOptionKey_ForceKeyFrame: kCFBooleanTrue] as CFDictionary : nil
    let status = VTCompressionSessionEncodeFrame(
      session,
      imageBuffer: pixelBuffer,
      presentationTimeStamp: CMTime(value: timestampUs, timescale: 1_000_000),
      duration: .invalid,
      frameProperties: properties,
      infoFlagsOut: nil
    ) { [weak self] status, _, sample in
      guard status == noErr, let sample else { return }
      self?.append(sample)
    }
    guard status == noErr else {
      throw LivenessVideoError("Could not encode the frame (\(status))")
    }
  }

  private func takeForceKeyFrame() -> Bool {
    stateQueue.sync {
      let force = forceKeyFrame
      forceKeyFrame = false
      return force
    }
  }

  private func append(_ sample: CMSampleBuffer) {
    stateQueue.async { [self] in
      if samples.isEmpty && !isKeyFrame(sample) { return }
      samples.append(sample)
      let newest = CMSampleBufferGetPresentationTimeStamp(sample)
      while let next = samples.indices.dropFirst().first(where: { isKeyFrame(samples[$0]) }),
        CMTimeSubtract(newest, CMSampleBufferGetPresentationTimeStamp(samples[next])) >= maxDuration
      {
        samples.removeFirst(next)
      }
    }
  }

  private func isKeyFrame(_ sample: CMSampleBuffer) -> Bool {
    guard
      let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false)
        as? [[CFString: Any]],
      let first = attachments.first
    else { return true }
    return !(first[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)
  }

  private func write(_ clip: [CMSampleBuffer], to url: URL) throws {
    try? FileManager.default.removeItem(at: url)
    do {
      let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
      let input = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: nil,
        sourceFormatHint: CMSampleBufferGetFormatDescription(clip[0])
      )
      input.expectsMediaDataInRealTime = false
      input.transform = CGAffineTransform(rotationAngle: CGFloat(rotation) * .pi / 180)
      guard writer.canAdd(input) else { throw LivenessVideoError("Could not add the video track") }
      writer.add(input)
      guard writer.startWriting() else {
        throw writer.error ?? LivenessVideoError("Could not start writing the video")
      }
      writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(clip[0]))
      for sample in clip {
        while !input.isReadyForMoreMediaData {
          guard writer.status == .writing else {
            throw writer.error ?? LivenessVideoError("Video writer stopped")
          }
          Thread.sleep(forTimeInterval: 0.005)
        }
        guard input.append(sample) else {
          throw writer.error ?? LivenessVideoError("Could not append a video sample")
        }
      }
      input.markAsFinished()
      let finished = DispatchSemaphore(value: 0)
      writer.finishWriting { finished.signal() }
      finished.wait()
      guard writer.status == .completed else {
        throw writer.error ?? LivenessVideoError("Could not finish writing the video")
      }
    } catch {
      try? FileManager.default.removeItem(at: url)
      throw error
    }
  }
}
