# Firebase Token Reporter

Firebase Token Reporter is utility class which enables integration with Firebase Cloud Messaging (FCM).
It's based on Instance ID Server API
[documented in full here](https://developers.google.com/instance-id/reference/server#create_registration_tokens_for_apns_tokens).

The purpose of this class is to be used in iOS app which does not directly work with Firebase; instead it connects with its own backend web API which uses Firebase for push notifications delivery.

This is often the case when iOS app client is added for a service already using Android / web front-ends. 

Ideally, this would not be needed and iOS app would deliver APNS token to its backend web API, which will then make server to server call to convert APNS token with FCM token. When that‘s not available (for whatever reason) then this is your only option apart from integrating Firebase/Core through CocoaPods. Which I never want to do since the damn thing is – out of the box – one of the most invasive 3rd party libraries I have seen.

## APNS / FCM Configuration

Your app should already be configured completely in Firebase Console / Settings / Cloud Messaging. In particular, you need to:

* create APNS Auth Key in Apple’s Developer Portal
* upload it to FCM Console and 
* setup other details for the app there

See the [overview of required steps](https://firebase.google.com/docs/cloud-messaging/ios/certs) in Firebase documentation for more details.

## Usage

Either in AppDelegate or anywhere you deem right – configure the singleton with the FCM server key and the APNS environment you are using.

```swift
private lazy var firebaseTokenReporter: FirebaseTokenReporter = {
	let ftr = FirebaseTokenReporter.shared
	if
		let serverKey = FirebaseTokenReporter.serverKey,
		let environment = FirebaseTokenReporter.activeEnvironment
	{
		ftr.configure(with: serverKey, for: environment)
	}
	return ftr
}()
```

Later, when you receive the token from APNS in AppDelegate, you call the only method there is:

```
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
	if let error = error {
		log(level: .error, error)
		return
	}
	guard let deviceToken = deviceToken else {
		log(level: .warning, "DeviceToken not received")
		return
	}

	let tokenParts = deviceToken.map { data -> String in
		return String(format: "%02.2hhx", data)
	}
	let token = tokenParts.joined()
	log(level: .info, "Received APNS DeviceToken: \( token )")

	firebaseTokenReporter.register(deviceToken: token, onQueue: .main) {
		[unowned self] fcmToken, firebaseError in

		if let firebaseError = firebaseError {
			self.log(level: .warning, firebaseError)
			return
		}

		self.fcmToken = fcmToken
		self.log(level: .info, "Received FCM token: \( fcmToken ?? "" )")
	}
}
```

Now you have FCM token and you can send it to your app’s service backend.