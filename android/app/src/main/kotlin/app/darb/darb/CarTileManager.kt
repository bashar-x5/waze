package app.darb.darb

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class CarTileManager(private val context: Context) {
    private val memoryCache = object : LruCache<String, Bitmap>(200) {
        override fun sizeOf(key: String, bitmap: Bitmap): Int = 1
    }

    private val diskCacheDir = File(context.cacheDir, "darb_car_tiles_v2").apply { mkdirs() }
    private val fetchExecutor = Executors.newFixedThreadPool(4)
    private val pendingRequests = mutableSetOf<String>()

    init {
        // Purge old watermarked CartoDB tiles if present
        try {
            File(context.cacheDir, "darb_car_tiles").deleteRecursively()
        } catch (_: Exception) {}
    }

    fun getTile(
        zoom: Int,
        x: Int,
        y: Int,
        isSatellite: Boolean,
        isDark: Boolean,
        onTileLoaded: () -> Unit
    ): Bitmap? {
        val type = if (isSatellite) "sat" else "osm"
        val key = "$zoom/$x/$y/$type"

        // 1. Check memory cache
        synchronized(memoryCache) {
            val cached = memoryCache.get(key)
            if (cached != null && !cached.isRecycled) return cached
        }

        // 2. Check disk cache
        val diskFile = File(diskCacheDir, "${type}_${zoom}_${x}_$y.png")
        if (diskFile.exists() && diskFile.length() > 0) {
            try {
                val diskBmp = BitmapFactory.decodeFile(diskFile.absolutePath)
                if (diskBmp != null) {
                    synchronized(memoryCache) {
                        memoryCache.put(key, diskBmp)
                    }
                    return diskBmp
                }
            } catch (_: Exception) {}
        }

        // 3. Avoid duplicate pending HTTP requests
        synchronized(pendingRequests) {
            if (pendingRequests.contains(key)) return null
            pendingRequests.add(key)
        }

        // 4. Download tile in background thread
        fetchExecutor.execute {
            try {
                // 100% Free, zero-API-key, zero-watermark official tile sources
                val urlStr = if (isSatellite) {
                    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$zoom/$y/$x"
                } else {
                    "https://tile.openstreetmap.org/$zoom/$x/$y.png"
                }

                val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 4000
                    readTimeout = 4000
                    setRequestProperty("User-Agent", "DarbNavigation/1.0 (contact: info@darb.app)")
                }

                if (conn.responseCode == 200) {
                    val bytes = conn.inputStream.use { it.readBytes() }
                    val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    if (bmp != null) {
                        try {
                            FileOutputStream(diskFile).use { it.write(bytes) }
                        } catch (_: Exception) {}

                        synchronized(memoryCache) {
                            memoryCache.put(key, bmp)
                        }
                        onTileLoaded()
                    }
                }
            } catch (_: Exception) {
            } finally {
                synchronized(pendingRequests) {
                    pendingRequests.remove(key)
                }
            }
        }

        return null
    }

    fun clear() {
        memoryCache.evictAll()
    }
}
