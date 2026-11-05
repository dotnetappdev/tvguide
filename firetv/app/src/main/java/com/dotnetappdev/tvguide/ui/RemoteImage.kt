package com.dotnetappdev.tvguide.ui

import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage

/**
 * Images for previews and screenshot tests, which can't fetch from the
 * network: maps an image URL to a bitmap loaded ahead of time.
 */
val LocalPreviewImages = staticCompositionLocalOf<((String) -> ImageBitmap?)?> { null }

/** A network image (logo or artwork); calls [onError] if it can't be shown. */
@Composable
fun RemoteImage(url: String, contentScale: ContentScale, modifier: Modifier = Modifier, onError: () -> Unit = {}) {
    val preview = LocalPreviewImages.current
    if (preview != null) {
        val bitmap = preview(url)
        if (bitmap != null) Image(bitmap, contentDescription = null, contentScale = contentScale, modifier = modifier)
        else LaunchedEffect(url) { onError() }
        return
    }
    AsyncImage(model = url, contentDescription = null, contentScale = contentScale, onError = { onError() }, modifier = modifier)
}
