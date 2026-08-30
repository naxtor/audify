package id.nabilfaris.audify

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class AudifyPluginTest {
    @Test
    fun onMethodCall_unknownMethod_reportsNotImplemented() {
        val plugin = AudifyPlugin()

        val call = MethodCall("getPlatformVersion", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).notImplemented()
    }

    @Test
    fun normalizeCaptureSize_clampsAndRoundsDownToAPowerOfTwo() {
        assertEquals(128, AudifyPlugin.normalizeCaptureSize(32, 128, 1024))
        assertEquals(512, AudifyPlugin.normalizeCaptureSize(900, 128, 1024))
        assertEquals(1024, AudifyPlugin.normalizeCaptureSize(4096, 128, 1024))
    }

    @Test
    fun normalizeCaptureSize_rejectsInvalidRequestsAndRanges() {
        assertFailsWith<IllegalArgumentException> {
            AudifyPlugin.normalizeCaptureSize(0, 128, 1024)
        }
        assertFailsWith<IllegalArgumentException> {
            AudifyPlugin.normalizeCaptureSize(256, 1024, 128)
        }
    }
}
