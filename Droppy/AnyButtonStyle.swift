//
//  AnyButtonStyle.swift
//  Droppy
//
//  Created helper for type-erasing ButtonStyles
//

import SwiftUI

/// Type-erased ButtonStyle to allow conditional styles
struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}
