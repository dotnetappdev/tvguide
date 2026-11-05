package com.dotnetappdev.tvguide.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Minimal HTTP GET on the IO dispatcher (no extra networking library needed). */
object Http {
    var userAgent = "TVGuide-FireTV/1.0"

    suspend fun get(url: String, timeoutMs: Int = 30_000): ByteArray = withContext(Dispatchers.IO) {
        val connection = open(url, timeoutMs)
        try {
            if (connection.responseCode !in 200..299) throw IOException("HTTP ${connection.responseCode} for $url")
            connection.inputStream.use { it.readBytes() }
        } finally {
            connection.disconnect()
        }
    }

    suspend fun getText(url: String, timeoutMs: Int = 30_000): String = String(get(url, timeoutMs), Charsets.UTF_8)

    /** Streams a large download straight to a file (used for the ~20 MB Freeview feed). */
    suspend fun download(url: String, to: File, timeoutMs: Int = 60_000) = withContext(Dispatchers.IO) {
        val connection = open(url, timeoutMs)
        try {
            if (connection.responseCode !in 200..299) throw IOException("HTTP ${connection.responseCode} for $url")
            val partial = File(to.parentFile, to.name + ".part")
            connection.inputStream.use { input -> partial.outputStream().use { input.copyTo(it) } }
            if (partial.length() < 1024) throw IOException("Download too small")
            if (!partial.renameTo(to)) {
                to.delete()
                partial.renameTo(to)
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun open(url: String, timeoutMs: Int): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = timeoutMs
            readTimeout = timeoutMs
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", userAgent)
        }
}
