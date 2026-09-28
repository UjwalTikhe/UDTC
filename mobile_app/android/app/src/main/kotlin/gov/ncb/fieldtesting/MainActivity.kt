package gov.ncb.fieldtesting

import android.telephony.SmsManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.nio.charset.StandardCharsets
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.MessageDigest
import org.opencv.android.OpenCVLoader
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.objdetect.ArucoDetector
import org.opencv.objdetect.DetectorParameters
import org.opencv.objdetect.Objdetect
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "in.gov.mha/sms"
    private val KEYSTORE_CHANNEL = "in.gov.mha/keystore"
    private val ARUCO_CHANNEL = "in.gov.mha/aruco"
    private val KEY_ALIAS = "mha_field_device_p256_v1"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSms") {
                val to = call.argument<String>("to")
                val message = call.argument<String>("message")
                try {
                    val smsManager = SmsManager.getDefault()
                    smsManager.sendTextMessage(to, null, message, null, null)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SMS_FAILED", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEYSTORE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "signPayload") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val payload = call.argument<String>("payload")
                    ?: throw IllegalArgumentException("Missing signing payload")
                val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                if (!keyStore.containsAlias(KEY_ALIAS)) {
                    val generator = KeyPairGenerator.getInstance(
                        KeyProperties.KEY_ALGORITHM_EC,
                        "AndroidKeyStore"
                    )
                    val builder = KeyGenParameterSpec.Builder(
                        KEY_ALIAS,
                        KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
                    )
                        .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                        .setDigests(KeyProperties.DIGEST_SHA256)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        try { builder.setIsStrongBoxBacked(true) } catch (_: Exception) {}
                    }
                    generator.initialize(builder.build())
                    generator.generateKeyPair()
                }
                val entry = keyStore.getEntry(KEY_ALIAS, null) as KeyStore.PrivateKeyEntry
                val signer = Signature.getInstance("SHA256withECDSA")
                signer.initSign(entry.privateKey)
                signer.update(payload.toByteArray(StandardCharsets.UTF_8))
                result.success(signer.sign().joinToString("") { "%02x".format(it) })
            } catch (e: Exception) {
                result.error("KEYSTORE_SIGN_FAILED", e.message, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ARUCO_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "detectMarkers") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (!OpenCVLoader.initDebug()) {
                result.error("OPENCV_UNAVAILABLE", "OpenCV native library could not be loaded.", null)
                return@setMethodCallHandler
            }
            try {
                val bytes = call.argument<ByteArray>("luma")
                    ?: throw IllegalArgumentException("Missing luma plane")
                val width = call.argument<Int>("width") ?: throw IllegalArgumentException("Missing width")
                val height = call.argument<Int>("height") ?: throw IllegalArgumentException("Missing height")
                val gray = Mat(height, width, CvType.CV_8UC1)
                gray.put(0, 0, bytes)
                val dictionary = Objdetect.getPredefinedDictionary(Objdetect.DICT_4X4_50)
                val corners = ArrayList<Mat>()
                val ids = Mat()
                val parameters = DetectorParameters()
                val detector = ArucoDetector(dictionary, parameters)
                detector.detectMarkers(gray, corners, ids)
                val markerIds = mutableListOf<Int>()
                val quadrants = mutableListOf<Int>()
                for (row in 0 until ids.rows()) {
                    markerIds.add(ids.get(row, 0)[0].toInt())
                    val points = corners[row].get(0, 0)
                    val x = (points[0] + corners[row].get(0, 1)[0] +
                        corners[row].get(0, 2)[0] + corners[row].get(0, 3)[0]) / 4.0
                    val y = (points[1] + corners[row].get(0, 1)[1] +
                        corners[row].get(0, 2)[1] + corners[row].get(0, 3)[1]) / 4.0
                    val quadrant = if (x < width / 2.0) {
                        if (y < height / 2.0) 0 else 2
                    } else {
                        if (y < height / 2.0) 1 else 3
                    }
                    quadrants.add(quadrant)
                }
                corners.forEach { it.release() }
                gray.release()
                ids.release()
                result.success(mapOf("ids" to markerIds, "quadrants" to quadrants))
            } catch (e: Exception) {
                result.error("ARUCO_DETECTION_FAILED", e.message, null)
            }
        }
    }
}
