//
//  SceneDelegate.swift
//  MultipeerVideo-Assignment
//
//  Created by cleanmac on 14/01/23.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        if UIDevice.current.userInterfaceIdiom == .pad {
            window?.rootViewController = HostVC()
        } else {
            window?.rootViewController = StreamerVC()
        }
        window?.makeKeyAndVisible()
    }
}

