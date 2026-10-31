package com.ply.mpd

import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioManager
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.provider.OpenableColumns
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val channelName = "ply/media"
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "mux" -> handleMux(call, result)
                "thumbnail" -> handleThumbnail(call, result)
                "getInitialIntent" -> handleGetInitialIntent(result)
                "readTextUri" -> handleReadTextUri(call, result)
                "resolveUriToFilePath" -> handleResolveUriToFilePath(call, result)
                "resolveRedirect" -> {
                    val inputUrl = call.argument<String>("url") ?: ""
                    val cookie = call.argument<String>("cookie") ?: ""
                    Thread {
                        try {
                            var currentUrl = inputUrl
                            var redirectCount = 0
                            val maxRedirects = 10
                            var lastBody = ""

                            while (redirectCount < maxRedirects) {
                                val urlObj = java.net.URL(currentUrl)
                                val conn = urlObj.openConnection() as java.net.HttpURLConnection
                                conn.instanceFollowRedirects = false
                                conn.requestMethod = "GET"
                                conn.connectTimeout = 12000
                                conn.readTimeout = 12000
                                conn.setRequestProperty(
                                    "User-Agent",
                                    "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36"
                                )
                                conn.setRequestProperty(
                                    "Accept",
                                    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
                                )
                                conn.setRequestProperty(
                                    "Accept-Language",
                                    "en-US,en;q=0.9,ar;q=0.8"
                                )
                                conn.setRequestProperty("Sec-Fetch-Dest", "document")
                                conn.setRequestProperty("Sec-Fetch-Mode", "navigate")
                                conn.setRequestProperty("Sec-Fetch-Site", "none")
                                conn.setRequestProperty("Upgrade-Insecure-Requests", "1")

                                if (cookie.isNotEmpty()) {
                                    conn.setRequestProperty("Cookie", cookie)
                                } else {
                                    val cookieManager = android.webkit.CookieManager.getInstance()
                                    val c1 = cookieManager.getCookie(currentUrl) ?: ""
                                    val c2 = cookieManager.getCookie("https://www.facebook.com") ?: ""
                                    val finalC = if (c1.isNotEmpty()) c1 else c2
                                    if (finalC.isNotEmpty()) {
                                        conn.setRequestProperty("Cookie", finalC)
                                    }
                                }

                                val status = conn.responseCode
                                val location = conn.getHeaderField("Location")

                                try {
                                    val stream = if (status in 200..299) conn.inputStream else conn.errorStream
                                    if (stream != null) {
                                        val reader = java.io.BufferedReader(java.io.InputStreamReader(stream))
                                        val sb = java.lang.StringBuilder()
                                        var line: String? = reader.readLine()
                                        var lineCount = 0
                                        while (line != null && lineCount < 1000) {
                                            sb.append(line).append("\n")
                                            line = reader.readLine()
                                            lineCount++
                                        }
                                        lastBody = sb.toString()
                                        reader.close()
                                    }
                                } catch (_: Exception) {}

                                conn.disconnect()

                                if (status in 300..399 && !location.isNullOrEmpty()) {
                                    val nextUrl = if (location.startsWith("http://") || location.startsWith("https://")) {
                                        location
                                    } else {
                                        java.net.URI(currentUrl).resolve(location).toString()
                                    }
                                    currentUrl = nextUrl
                                    redirectCount++
                                    continue
                                }
                                break
                            }

                            activity?.runOnUiThread {
                                val resMap = hashMapOf<String, Any>(
                                    "resolvedUrl" to currentUrl,
                                    "body" to lastBody
                                )
                                result.success(resMap)
                            }
                        } catch (e: Exception) {
                            activity?.runOnUiThread {
                                val resMap = hashMapOf<String, Any>(
                                    "resolvedUrl" to inputUrl,
                                    "body" to ""
                                )
                                result.success(resMap)
                            }
                        }
                    }.start()
                }
                "getCookies" -> {
                    val url = call.argument<String>("url") ?: "https://m.facebook.com"
                    try {
                        val cookieManager = android.webkit.CookieManager.getInstance()
                        val cookies1 = cookieManager.getCookie("https://m.facebook.com") ?: ""
                        val cookies2 = cookieManager.getCookie("https://facebook.com") ?: ""
                        val cookies3 = cookieManager.getCookie("https://www.facebook.com") ?: ""
                        val cookies4 = if (url.isNotEmpty() && url.startsWith("http")) (cookieManager.getCookie(url) ?: "") else ""
                        val allCookies = listOf(cookies1, cookies2, cookies3, cookies4)
                            .filter { it.isNotBlank() }
                            .joinToString("; ")
                        result.success(allCookies)
                    } catch (e: Exception) {
                        result.success("")
                    }
                }
                "setCookies", "setCookie" -> {
                    val cookieStr = call.argument<String>("cookies")
                        ?: call.argument<String>("cookie") ?: ""
                    val clearExisting = call.argument<Boolean>("clearExisting") ?: true
                    try {
                        val cookieManager = android.webkit.CookieManager.getInstance()
                        cookieManager.setAcceptCookie(true)

                        val applyCookies = {
                            val domains = listOf(
                                "https://m.facebook.com",
                                "https://facebook.com",
                                "https://www.facebook.com"
                            )
                            val items = cookieStr.split(";")
                            for (item in items) {
                                val pair = item.trim()
                                if (pair.isEmpty() || !pair.contains("=")) continue
                                val eqIdx = pair.indexOf("=")
                                val key = pair.substring(0, eqIdx).trim()
                                val value = pair.substring(eqIdx + 1).trim()
                                if (key.isEmpty()) continue

                                val domainPayload = "$key=$value; domain=.facebook.com; path=/; secure; SameSite=None"
                                val simplePayload = "$key=$value; path=/"

                                for (d in domains) {
                                    try {
                                        cookieManager.setCookie(d, domainPayload)
                                        cookieManager.setCookie(d, simplePayload)
                                    } catch (_: Exception) {}
                                }
                            }
                            cookieManager.flush()
                            activity?.runOnUiThread {
                                result.success(true)
                            }
                        }

                        if (clearExisting) {
                            cookieManager.removeAllCookies {
                                cookieManager.flush()
                                applyCookies()
                            }
                        } else {
                            applyCookies()
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "clearCookies" -> {
                    try {
                        val cookieManager = android.webkit.CookieManager.getInstance()
                        cookieManager.removeAllCookies {
                            cookieManager.flush()
                            activity?.runOnUiThread {
                                result.success(true)
                            }
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val data = extractIntentData(intent)
        if (data != null) {
            channel?.invokeMethod("onIntent", data)
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val next = if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                (current + 1).coerceAtMost(max)
            } else {
                (current - 1).coerceAtLeast(0)
            }
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, next, 0)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun handleGetInitialIntent(result: MethodChannel.Result) {
        result.success(extractIntentData(intent))
    }

    private fun extractIntentData(intent: Intent?): Map<String, String?>? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action == Intent.ACTION_MAIN) return null

        return when (action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data ?: return null
                val uriStr = uri.toString()
                val mimeType = intent.type
                    ?: try { contentResolver.getType(uri) } catch (_: Exception) { null }
                    ?: guessMime(uriStr)
                val displayName = queryDisplayName(uri)
                mapOf("uri" to uriStr, "mimeType" to mimeType, "displayName" to displayName)
            }
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val streamUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (streamUri != null) {
                    val uriStr = streamUri.toString()
                    val mimeType = intent.type
                        ?: try { contentResolver.getType(streamUri) } catch (_: Exception) { null }
                        ?: guessMime(uriStr)
                    val displayName = queryDisplayName(streamUri)
                    return mapOf("uri" to uriStr, "mimeType" to mimeType, "displayName" to displayName)
                }
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (text != null && text.isNotBlank()) {
                    mapOf("uri" to text, "mimeType" to guessMime(text), "displayName" to null)
                } else null
            }
            else -> null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme != "content") return null
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) cursor.getString(idx) else null
                    } else null
                }
        } catch (_: Exception) { null }
    }

    private fun guessMime(uriOrPath: String): String? {
        val lower = uriOrPath.lowercase()
        return when {
            lower.endsWith(".mpd") -> "application/dash+xml"
            lower.endsWith(".mp4") -> "video/mp4"
            lower.endsWith(".m4v") -> "video/mp4"
            lower.endsWith(".webm") -> "video/webm"
            lower.endsWith(".mkv") -> "video/x-matroska"
            else -> null
        }
    }

    private fun handleResolveUriToFilePath(call: MethodCall, result: MethodChannel.Result) {
        val uriStr = call.argument<String>("uri")
        if (uriStr == null) {
            result.success(null)
            return
        }
        try {
            val uri = Uri.parse(uriStr)
            if (uri.scheme != "content") {
                result.success(if (uri.scheme == "file") uri.path else null)
                return
            }
            val cursor = contentResolver.query(uri, arrayOf("_data"), null, null, null)
            val realPath = cursor?.use {
                if (it.moveToFirst()) {
                    val idx = it.getColumnIndex("_data")
                    if (idx >= 0) it.getString(idx) else null
                } else null
            }
            if (realPath != null && File(realPath).exists()) {
                result.success(realPath)
            } else {
                result.success(null)
            }
        } catch (_: Exception) {
            result.success(null)
        }
    }

    private fun handleReadTextUri(call: MethodCall, result: MethodChannel.Result) {
        val uriStr = call.argument<String>("uri")
        if (uriStr == null) {
            result.error("bad_args", "uri required", null)
            return
        }
        try {
            val uri = Uri.parse(uriStr)
            val text = when (uri.scheme) {
                "file" -> {
                    val path = uri.path ?: throw Exception("null path")
                    File(path).readText()
                }
                "content" -> {
                    contentResolver.openInputStream(uri)?.use { stream ->
                        stream.readBytes().toString(Charsets.UTF_8)
                    } ?: throw Exception("null stream")
                }
                else -> throw Exception("unsupported scheme: ${uri.scheme}")
            }
            result.success(text)
        } catch (e: Exception) {
            result.error("read_failed", e.message, null)
        }
    }

    private fun handleMux(call: MethodCall, result: MethodChannel.Result) {
        val videoPath = call.argument<String>("videoPath")
        val audioPath = call.argument<String>("audioPath")
        val outputPath = call.argument<String>("outputPath")
        if (videoPath == null || outputPath == null) {
            result.error("bad_args", "videoPath/outputPath required", null)
            return
        }

        Thread {
            var muxer: MediaMuxer? = null
            val videoExtractor = MediaExtractor()
            val hasAudioInput = audioPath != null && File(audioPath).exists() && File(audioPath).length() > 0L
            val audioExtractor = if (hasAudioInput) MediaExtractor() else null
            val outFile = File(outputPath)

            try {
                outFile.parentFile?.mkdirs()
                if (outFile.exists()) outFile.delete()

                videoExtractor.setDataSource(videoPath)
                var videoTrackIn = -1
                var videoFormat: MediaFormat? = null

                for (i in 0 until videoExtractor.trackCount) {
                    val fmt = videoExtractor.getTrackFormat(i)
                    val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
                    if (mime.startsWith("video/")) {
                        videoTrackIn = i
                        videoFormat = fmt
                        break
                    }
                }

                if (videoTrackIn < 0 || videoFormat == null) {
                    if (File(videoPath).exists() && File(videoPath).length() > 0L) {
                        File(videoPath).copyTo(outFile, overwrite = true)
                        activity?.runOnUiThread { result.success(true) }
                    } else {
                        activity?.runOnUiThread { result.error("mux_failed", "No video track found", null) }
                    }
                    return@Thread
                }

                var audioTrackIn = -1
                var audioFormat: MediaFormat? = null
                if (audioExtractor != null && audioPath != null) {
                    try {
                        audioExtractor.setDataSource(audioPath)
                        for (i in 0 until audioExtractor.trackCount) {
                            val fmt = audioExtractor.getTrackFormat(i)
                            val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
                            if (mime.startsWith("audio/")) {
                                audioTrackIn = i
                                audioFormat = fmt
                                break
                            }
                        }
                    } catch (_: Exception) {}
                }

                muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                val videoTrackOut = muxer.addTrack(videoFormat)
                val audioTrackOut = if (audioTrackIn >= 0 && audioFormat != null) {
                    try {
                        muxer.addTrack(audioFormat)
                    } catch (_: Exception) {
                        -1
                    }
                } else -1

                muxer.start()

                val bufSize = 2 * 1024 * 1024
                val buf = ByteBuffer.allocateDirect(bufSize)
                val info = MediaCodec.BufferInfo()

                // 1. Write video samples
                videoExtractor.selectTrack(videoTrackIn)
                while (true) {
                    buf.clear()
                    val sampleSize = videoExtractor.readSampleData(buf, 0)
                    if (sampleSize < 0) break
                    info.offset = 0
                    info.size = sampleSize
                    info.presentationTimeUs = videoExtractor.sampleTime
                    info.flags = videoExtractor.sampleFlags
                    muxer.writeSampleData(videoTrackOut, buf, info)
                    videoExtractor.advance()
                }

                // 2. Write audio samples if available
                if (audioTrackIn >= 0 && audioTrackOut >= 0 && audioExtractor != null) {
                    audioExtractor.selectTrack(audioTrackIn)
                    while (true) {
                        buf.clear()
                        val sampleSize = audioExtractor.readSampleData(buf, 0)
                        if (sampleSize < 0) break
                        info.offset = 0
                        info.size = sampleSize
                        info.presentationTimeUs = audioExtractor.sampleTime
                        info.flags = audioExtractor.sampleFlags
                        muxer.writeSampleData(audioTrackOut, buf, info)
                        audioExtractor.advance()
                    }
                }

                muxer.stop()

                if (outFile.exists() && outFile.length() > 0L) {
                    activity?.runOnUiThread { result.success(true) }
                } else {
                    File(videoPath).copyTo(outFile, overwrite = true)
                    activity?.runOnUiThread { result.success(true) }
                }
            } catch (t: Throwable) {
                try {
                    if (!outFile.exists() || outFile.length() == 0L) {
                        if (File(videoPath).exists() && File(videoPath).length() > 0L) {
                            File(videoPath).copyTo(outFile, overwrite = true)
                            activity?.runOnUiThread { result.success(true) }
                            return@Thread
                        }
                    }
                } catch (_: Exception) {}
                activity?.runOnUiThread { result.error("mux_failed", t.message ?: "Mux error", null) }
            } finally {
                try { muxer?.release() } catch (_: Exception) {}
                try { videoExtractor.release() } catch (_: Exception) {}
                try { audioExtractor?.release() } catch (_: Exception) {}
            }
        }.start()
    }

    private fun handleThumbnail(call: MethodCall, result: MethodChannel.Result) {
        val videoPath = call.argument<String>("videoPath")
        val outputPath = call.argument<String>("outputPath")
        val timeUs = (call.argument<Number>("timeUs") ?: 1_000_000L).toLong()
        if (videoPath == null || outputPath == null) {
            result.error("bad_args", "videoPath/outputPath required", null)
            return
        }

        Thread {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(videoPath)
                var frame: Bitmap? = null
                try {
                    frame = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                } catch (_: Exception) {}
                if (frame == null) {
                    try {
                        frame = retriever.getFrameAtTime(0L, MediaMetadataRetriever.OPTION_CLOSEST)
                    } catch (_: Exception) {}
                }
                if (frame == null) {
                    try {
                        frame = retriever.frameAtTime
                    } catch (_: Exception) {}
                }
                if (frame == null) {
                    activity?.runOnUiThread { result.success(false) }
                    return@Thread
                }

                val targetWidth = 400
                val scale = targetWidth.toFloat() / frame.width.toFloat()
                val targetHeight = (frame.height * scale).toInt().coerceAtLeast(1)
                val scaled = Bitmap.createScaledBitmap(frame, targetWidth, targetHeight, true)

                val outFile = File(outputPath)
                outFile.parentFile?.mkdirs()
                FileOutputStream(outFile).use { fos ->
                    scaled.compress(Bitmap.CompressFormat.JPEG, 85, fos)
                }

                if (scaled !== frame) frame.recycle()
                scaled.recycle()
                activity?.runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                activity?.runOnUiThread { result.success(false) }
            } finally {
                try { retriever.release() } catch (_: Exception) {}
            }
        }.start()
    }
}
