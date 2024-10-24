// Copyright 2015-present 650 Industries. All rights reserved.

package versioned.host.exp.exponent

import android.net.Uri
import com.facebook.react.packagerconnection.ReconnectingWebSocket
import expo.modules.kotlin.devtools.ExpoRequestCdpInterceptor
import java.io.Closeable

class ExpoNetworkInterceptor(private val appUrl: Uri) : Closeable, ExpoRequestCdpInterceptor.Delegate {
  private var metroConnection: ReconnectingWebSocket? = null

  init {
    onResume()
  }

  fun onResume() {
    metroConnection = createMetroConnection(appUrl)
    ExpoRequestCdpInterceptor.setDelegate(this)
  }

  fun onPause() {
    ExpoRequestCdpInterceptor.setDelegate(null)
    metroConnection?.closeQuietly()
    metroConnection = null
  }

  //region Closeable implementations
  override fun close() {
    onPause()
  }
  //endregion Closeable implementations

  //region ExpoRequestCdpInterceptor.Delegate implementations
  override fun dispatch(event: String) {
    metroConnection?.sendMessage(event)
  }
  //endregion ExpoRequestCdpInterceptor.Delegate implementations
}

private fun createMetroConnection(appUrl: Uri): ReconnectingWebSocket {
  val connection = ReconnectingWebSocket(
    createNetworkInspectorUrl(appUrl),
    null,
    null
  )
  connection.connect()
  return connection
}

private fun createNetworkInspectorUrl(appUrl: Uri): String {
  val host = appUrl.host ?: "localhost"
  val port = if (appUrl.port > 0) appUrl.port else 8081
  val scheme = if (appUrl.scheme == "https") "wss" else "ws"
  return "$scheme://$host:$port/inspector/network"
}
