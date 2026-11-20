//
//  NormalButtonStyle.swift
//  KoveMirror
//
//  Created by Matti Mustonen on 17.10.2026.
//
import SwiftUI

struct NormalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RideButtonStyle(primary: false).makeBody(configuration: configuration)
    }
}

extension ButtonStyle where Self == NormalButtonStyle {
    static var normalButtonStyle: NormalButtonStyle {
        NormalButtonStyle()
    }
}

extension View {
    func normalButtonStyle() -> some View {
        buttonStyle(.normalButtonStyle)
    }
}
