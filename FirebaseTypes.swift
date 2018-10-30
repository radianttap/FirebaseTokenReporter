//
//  FirebaseTypes.swift
//  Firebase
//
//  Copyright © 2017 Aleksandar Vacić, Radiant Tap
//  MIT License · http://choosealicense.com/licenses/mit/
//

import Foundation


public enum APNSEnvironment {
	case development
	case production
}


public enum FirebaseError: Error {
	case unknownError(Swift.Error?)
	case urlError(URLError)
	case invalidResponse
	case unexpectedResponse(HTTPURLResponse, String?)
	case missingResponseBody
	case unexpectedResponseBody(String?)
}
