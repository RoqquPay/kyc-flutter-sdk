package com.roqqu.kyc_engine

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMethodCodec
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class KycEnginePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val recorders = ConcurrentHashMap<Int, LivenessVideoRecorder>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val writer = Executors.newSingleThreadExecutor()
    private var nextId = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        channel = MethodChannel(messenger, "kyc_engine/video", StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        recorders.values.forEach { it.release() }
        recorders.clear()
        writer.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "start" -> start(call, result)
            "frame" -> frame(call, result)
            "finish" -> finish(call, result)
            "release" -> {
                call.argument<Int>("id")?.let { recorders.remove(it) }?.release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(call: MethodCall, result: Result) {
        if (call.argument<String>("format") != "nv21") {
            return result.error("unsupported_format", "Android recording expects NV21 frames", null)
        }
        try {
            val recorder = LivenessVideoRecorder(
                width = call.argument<Int>("width")!!,
                height = call.argument<Int>("height")!!,
                rotation = call.argument<Int>("rotation")!!,
                fps = call.argument<Int>("fps")!!,
                bitrate = call.argument<Int>("bitrate")!!,
                maxDurationUs = call.argument<Number>("maxDurationUs")!!.toLong(),
            )
            val id = nextId++
            recorders[id] = recorder
            result.success(id)
        } catch (e: Exception) {
            result.error("start_failed", e.message, null)
        }
    }

    private fun frame(call: MethodCall, result: Result) {
        val recorder = call.argument<Int>("id")?.let { recorders[it] }
            ?: return result.error("unknown_recorder", "No recorder for this id", null)
        recorder.encode(
            call.argument<ByteArray>("bytes")!!,
            call.argument<Int>("bytesPerRow")!!,
            call.argument<Number>("timestampUs")!!.toLong(),
        ) { error ->
            mainHandler.post {
                if (error == null) result.success(null) else result.error("frame_failed", error.message, null)
            }
        }
    }

    private fun finish(call: MethodCall, result: Result) {
        val recorder = call.argument<Int>("id")?.let { recorders[it] }
            ?: return result.error("unknown_recorder", "No recorder for this id", null)
        val path = call.argument<String>("path")!!
        writer.execute {
            val outcome = runCatching { recorder.finish(path) }
            mainHandler.post {
                outcome.fold({ result.success(it) }, { result.error("finish_failed", it.message, null) })
            }
        }
    }
}
