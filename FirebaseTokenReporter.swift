//
//  FirebaseTokenReporter.swift
//  Firebase
//
//  Copyright © 2017 Aleksandar Vacić, Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
#elseif os(OSX)
    import AppKit
    import Foundation
#endif

/// Firebase Token Reporter is simple class that enables integration with Firebase Cloud Messaging.
/// It's based on Instance ID Server API
/// [documented in full here](https://developers.google.com/instance-id/reference/server#create_registration_tokens_for_apns_tokens).
///
/// The purpose of this class is to be used in iOS app which do not directly work with Firebase,
///	but connect with own backend web API which uses Firebase for push notifications delivery.
///	This is often the case when iOS app client is added for a service already using Android / web front-ends.
///
///	Ideally, this would not be needed and iOS app would deliver APNS token to its backend web API, which
///	will then make server to server call to convert APNS token with FCM token. When that‘s not available
///	(for whatever reason) then this is your only option apart from integrating Firebase/Core through CocoaPods.
///
/// Your app should already be configured completely in Firebase Console / Settings / Cloud Messaging.
/// In particular, you need to create APNS Auth Key, upload it to FCM Console and setup other details for the app.
///	See the [overview of required steps](https://firebase.google.com/docs/cloud-messaging/ios/certs) in Firebase documentation.
public class FirebaseTokenReporter {
	///	Returns FCM token or Error
	public typealias Callback = (String?, FirebaseError?) -> Void
	///
	private typealias JSON = [String: Any]

	/// Returns the singleton reporter instance.
	///	It‘s useless before you call `configure()` and supply FCM server key
    public static let shared = FirebaseTokenReporter()
    private init() {}

	private var fcmServerKey: String?
	private var environment: APNSEnvironment?
}

extension FirebaseTokenReporter {
	/// Configures the reporter with a FCM Server Key and APNS environment
	public func configure(with fcmServerKey: String, for environment: APNSEnvironment) {
		self.fcmServerKey = fcmServerKey
		self.environment = environment
	}

	/// Converts the APNS token into FCM token
	///
	/// - Parameter deviceToken: String value of the deviceToken received from APNS in AppDelegate.
	/// - Parameter onQueue: OperationQueue on which to execute `callback`.
	/// - Parameter callback: Passes result back: FCM token string or Error
	public func register(deviceToken: String, onQueue queue: OperationQueue? = nil, callback: @escaping Callback) {
		let urlRequest = buildRequest(with: deviceToken)

		let task = URLSession.shared.dataTask(with: urlRequest) {
			data, urlResponse, error in

			if let error = error {
				OperationQueue.execute(callback(nil, .urlError(error as! URLError)), onQueue: queue)
				return
			}

			guard let httpResponse = urlResponse as? HTTPURLResponse else {
				OperationQueue.execute(callback(nil, .invalidResponse), onQueue: queue)
				return
			}

			guard let data = data else {
				OperationQueue.execute(callback(nil, .missingResponseBody), onQueue: queue)
				return
			}
			let stringResponse = String(data: data, encoding: .utf8)

			if !(200..<300).contains(httpResponse.statusCode) {
				OperationQueue.execute(callback(nil, .unexpectedResponse(httpResponse, stringResponse)), onQueue: queue)
				return
			}

			guard
				let obj = try? JSONSerialization.jsonObject(with: data, options: []),
				let json = obj as? JSON
			else {
				OperationQueue.execute(callback(nil, .unexpectedResponseBody(stringResponse)), onQueue: queue)
				return
			}

			guard
				let tokens = json["results"] as? [JSON],
				let token = tokens.first,
				let fcmToken = token["registration_token"] as? String
			else {
				OperationQueue.execute(callback(nil, .unexpectedResponseBody(stringResponse)), onQueue: queue)
				return
			}

			OperationQueue.execute(callback(fcmToken, nil), onQueue: queue)
		}
		task.resume()
	}
}

private extension FirebaseTokenReporter {
	//	MARK: Internal

	func buildRequest(with deviceToken: String) -> URLRequest {
		guard
			let fcmServerKey = fcmServerKey,
			let environment = environment
		else {
			fatalError("FCM Server Key and/or Environment not set, please call `configure()` method first")
		}

		var urlRequest = URLRequest(url: baseURL)
		urlRequest.httpMethod = "POST"
		urlRequest.addValue("key=\( fcmServerKey )", forHTTPHeaderField: "Authorization")
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

		var json: JSON = [:]
		json["application"] = appIdentifier
		json["sandbox"] = environment == .development
		json["apns_tokens"] = [deviceToken]

		do {
			let body = try JSONSerialization.data(withJSONObject: json)
			urlRequest.httpBody = body
			return urlRequest

		} catch let error {
			fatalError(error.localizedDescription)
		}
	}


	//	MARK: Various local properties

	var userAgent: String {
		#if os(iOS) || os(tvOS) || os(watchOS)
			let currentDevice = UIDevice.current
			let osVersion = currentDevice.systemVersion.replacingOccurrences(of: ".", with: "_")
			return "Mozilla/5.0 (\(currentDevice.model); CPU iPhone OS \(osVersion) like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Mobile/13T534YI"
		#elseif os(OSX)
			let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
			let versionString = osVersion.replacingOccurrences(of: ".", with: "_")
			return "Mozilla/5.0 (Macintosh; Intel Mac OS X \(versionString)) AppleWebKit/603.2.4 (KHTML, like Gecko) \(self.appName)/\(self.appVersion)"
		#endif
	}

	var baseURL: URL {
		return URL(string: "https://iid.googleapis.com/iid/v1:batchImport")!
	}

	var appName: String {
		return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "(not set)"
	}

	var appIdentifier: String {
		return Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String  ?? "(not set)"
	}

	var appVersion: String {
		return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String  ?? "(not set)"
	}

	var appBuild: String {
		return Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String  ?? "(not set)"
	}
}


private extension OperationQueue {
	static func execute(_ block: @autoclosure @escaping () -> Void, onQueue queue: OperationQueue?) {
		if let queue = queue {
			queue.addOperation { block() }
			return
		}
		block()
	}
}
