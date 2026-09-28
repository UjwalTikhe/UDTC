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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "in.gov.mha/sms"
    private val KEYSTORE_CHANNEL = "in.gov.mha/keystore"
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
    }
}
