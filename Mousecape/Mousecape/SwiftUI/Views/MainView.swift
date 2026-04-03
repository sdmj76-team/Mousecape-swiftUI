//
//  MainView.swift
//  Mousecape
//
//  Main view with page-based navigation (Home / Settings)
//  Uses toolbar buttons for page switching
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    var body: some View {
        ZStack {
            if appState.isWindowVisible {
                switch appState.currentPage {
                case .home:
                    HomeView()
                case .settings:
                    SettingsView()
                }

                // Loading overlay
                if appState.isLoading {
                    LoadingOverlayView(message: appState.loadingMessage)
                }
            } else {
                // Empty view when window is hidden - releases all child views and their caches
                Color.clear
            }
        }
        .alert(
            appState.importResultIsSuccess ? String(localized: "Import Complete") : String(localized: "Import Failed"),
            isPresented: Binding(
                get: { appState.showImportResult },
                set: { appState.showImportResult = $0 }
            )
        ) {
            Button("OK") {
                appState.showImportResult = false
            }
        } message: {
            Text(appState.importResultMessage)
        }
        .alert(
            appState.operationResultIsSuccess ? String(localized: "Success") : String(localized: "Error"),
            isPresented: Binding(
                get: { appState.showOperationResult },
                set: { appState.showOperationResult = $0 }
            )
        ) {
            Button("OK") {
                appState.showOperationResult = false
            }
        } message: {
            Text(appState.operationResultMessage)
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlayView: View {
    let message: String

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle())

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(32)
            .adaptiveGlass(in: RoundedRectangle(cornerRadius: 16))
            .adaptiveShadow()
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environment(AppState.shared)
}
