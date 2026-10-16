package com.roqqu.kyc_engine

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import java.io.File
import java.nio.ByteBuffer

class LivenessVideoRecorder(
    private val width: Int,
    private val height: Int,
    private val rotation: Int,
    fps: Int,
    bitrate: Int,
    private val maxDurationUs: Long,
) {
    private class Sample(val data: ByteArray, val ptsUs: Long, val isKey: Boolean)

    private val thread = HandlerThread("KycVideoEncoder").apply { start() }
    private val handler = Handler(thread.looper)
    private val lock = Any()
    private val samples = ArrayDeque<Sample>()
    private val bufferInfo = MediaCodec.BufferInfo()
    private var outputFormat: MediaFormat? = null
    private val codec: MediaCodec

    @Volatile
    private var released = false

    init {
        try {
            codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
                setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
                setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }
            try {
                codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                codec.start()
            } catch (e: Exception) {
                codec.release()
                throw e
            }
        } catch (e: Exception) {
            thread.quitSafely()
            throw e
        }
    }

    fun encode(nv21: ByteArray, bytesPerRow: Int, ptsUs: Long, done: (Throwable?) -> Unit) {
        handler.post {
            if (released) return@post done(null)
            val error = runCatching {
                queueFrame(nv21, bytesPerRow, ptsUs)
                drain()
            }.exceptionOrNull()
            done(error)
        }
    }

    fun finish(path: String): Boolean {
        val (snapshot, format) = synchronized(lock) {
            val copy = samples.toList()
            samples.clear()
            copy to outputFormat
        }
        requestKeyFrame()
        if (format == null || snapshot.isEmpty()) return false
        val newest = snapshot.last().ptsUs
        val start = snapshot.indexOfFirst { it.isKey && newest - it.ptsUs <= maxDurationUs }
        if (start < 0) return false
        write(path, snapshot.subList(start, snapshot.size), format)
        return true
    }

    fun release() {
        released = true
        handler.post {
            runCatching { codec.stop() }
            runCatching { codec.release() }
            thread.quitSafely()
        }
    }

    private fun queueFrame(nv21: ByteArray, bytesPerRow: Int, ptsUs: Long) {
        val index = codec.dequeueInputBuffer(INPUT_TIMEOUT_US)
        if (index < 0) return
        val image = codec.getInputImage(index) ?: error("Encoder does not expose an input image")
        val y = image.planes[0]
        val u = image.planes[1]
        val v = image.planes[2]
        val yBuffer = y.buffer
        for (row in 0 until height) {
            yBuffer.position(row * y.rowStride)
            yBuffer.put(nv21, row * bytesPerRow, width)
        }
        val chromaOffset = bytesPerRow * height
        val uBuffer = u.buffer
        val vBuffer = v.buffer
        for (row in 0 until height / 2) {
            val source = chromaOffset + row * bytesPerRow
            val uRow = row * u.rowStride
            val vRow = row * v.rowStride
            for (col in 0 until width / 2) {
                vBuffer.put(vRow + col * v.pixelStride, nv21[source + col * 2])
                uBuffer.put(uRow + col * u.pixelStride, nv21[source + col * 2 + 1])
            }
        }
        codec.queueInputBuffer(index, 0, width * height * 3 / 2, ptsUs, 0)
    }

    private fun drain() {
        while (true) {
            val index = codec.dequeueOutputBuffer(bufferInfo, 0)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> return
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> synchronized(lock) { outputFormat = codec.outputFormat }
                index < 0 -> Unit
                else -> {
                    val isConfig = bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (!isConfig && bufferInfo.size > 0) {
                        val buffer = codec.getOutputBuffer(index) ?: error("Encoder returned no output buffer")
                        buffer.position(bufferInfo.offset)
                        buffer.limit(bufferInfo.offset + bufferInfo.size)
                        val data = ByteArray(bufferInfo.size).also { buffer.get(it) }
                        val isKey = bufferInfo.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
                        append(Sample(data, bufferInfo.presentationTimeUs, isKey))
                    }
                    codec.releaseOutputBuffer(index, false)
                }
            }
        }
    }

    private fun append(sample: Sample) = synchronized(lock) {
        if (samples.isEmpty() && !sample.isKey) return@synchronized
        samples.addLast(sample)
        while (true) {
            val next = samples.withIndex().firstOrNull { it.index > 0 && it.value.isKey } ?: break
            if (sample.ptsUs - next.value.ptsUs < maxDurationUs) break
            repeat(next.index) { samples.removeFirst() }
        }
    }

    private fun requestKeyFrame() {
        if (released) return
        runCatching {
            codec.setParameters(Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_REQUEST_SYNC_FRAME, 0) })
        }
    }

    private fun write(path: String, clip: List<Sample>, format: MediaFormat) {
        val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            muxer.setOrientationHint(rotation)
            val track = muxer.addTrack(format)
            muxer.start()
            val base = clip.first().ptsUs
            val info = MediaCodec.BufferInfo()
            for (sample in clip) {
                val flags = if (sample.isKey) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
                info.set(0, sample.data.size, sample.ptsUs - base, flags)
                muxer.writeSampleData(track, ByteBuffer.wrap(sample.data), info)
            }
            muxer.stop()
        } catch (e: Exception) {
            File(path).delete()
            throw e
        } finally {
            runCatching { muxer.release() }
        }
    }

    private companion object {
        const val INPUT_TIMEOUT_US = 10_000L
    }
}
