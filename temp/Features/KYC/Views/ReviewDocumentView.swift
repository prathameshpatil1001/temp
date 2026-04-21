import SwiftUI

struct ReviewDocumentView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showError = false
    @State private var previewVisible = false
    @State private var shakeTrigger: CGFloat = 0

    var body: some View {
        ZStack {
            DS.surface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        progressSection
                            .padding(.top, 16)

                        reviewCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
                }

                bottomActions
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !path.isEmpty { path.removeLast() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.primary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
            }

            ToolbarItem(placement: .principal) {
                Text("Review Document")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.primary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                previewVisible = true
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 8) {
                progressStep(title: "Identity", state: .current)
                progressConnector(isActive: false)
                progressStep(title: "Address", state: .upcoming)
                progressConnector(isActive: false)
                progressStep(title: "Income", state: .upcoming)
            }

            Text("Step 1 of 3")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DS.textSecondary)
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Check your document")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.primary)

                Text("Make sure all details are clearly visible and not blurred.")
                    .font(.system(size: 16))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            documentPreview

            checklistSection

            if showError {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(DS.warning)

                    Text("Image unclear. Please upload a clearer photo.")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity)
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }

    private var documentPreview: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        DS.primary.opacity(0.12),
                        DS.primary.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(1.58, contentMode: .fit)
            .overlay {
                VStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                        .frame(width: 210, height: 132)
                        .overlay {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(DS.primary.opacity(0.12))
                                    .frame(width: 60, height: 76)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 22, weight: .medium))
                                            .foregroundStyle(DS.primary)
                                    }

                                VStack(alignment: .leading, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.primary.opacity(0.22))
                                        .frame(width: 90, height: 10)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.primary.opacity(0.14))
                                        .frame(width: 72, height: 10)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.primary.opacity(0.14))
                                        .frame(width: 86, height: 10)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.primary.opacity(0.10))
                                        .frame(width: 58, height: 10)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(16)
                        }

                    Text("Preview of uploaded document")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.primary)
                }
                .padding(20)
                .opacity(previewVisible ? 1 : 0)
                .scaleEffect(previewVisible ? 1 : 0.96)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(showError ? DS.warning.opacity(0.45) : Color.clear, lineWidth: 1.5)
            )
            .modifier(ShakeEffect(animatableData: shakeTrigger))
            .accessibilityLabel("Uploaded identity document preview")
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            checklistRow(text: "All text is readable")
            checklistRow(text: "Document is not cropped")
            checklistRow(text: "Image is not blurry")
        }
    }

    private func checklistRow(text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.primary)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 16) {
            Divider()

            PrimaryBtn(title: "Looks Good", disabled: showError) {
                if showError {
                    withAnimation(.easeOut(duration: 0.2)) {
                        shakeTrigger += 1
                    }
                    return
                }

                path.append(KYCRoute.eSignature)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Button {
                if !path.isEmpty { path.removeLast() } else { dismiss() }
            } label: {
                Text("Retake / Upload Again")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DS.primary, lineWidth: 1.5)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(DS.surface)
    }

    private func progressStep(title: String, state: StepState) -> some View {
        VStack(spacing: 8) {
            ZStack {
                switch state {
                case .completed:
                    Circle()
                        .fill(DS.primary)
                        .frame(width: 30, height: 30)

                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)

                case .current:
                    Circle()
                        .stroke(DS.primary, lineWidth: 2)
                        .frame(width: 30, height: 30)

                    Circle()
                        .fill(DS.primaryLight)
                        .frame(width: 16, height: 16)

                case .upcoming:
                    Circle()
                        .fill(Color(white: 0.9))
                        .frame(width: 30, height: 30)
                }
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(state == .current ? DS.primary : DS.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func progressConnector(isActive: Bool) -> some View {
        Capsule()
            .fill(isActive ? DS.primary : Color(white: 0.9))
            .frame(height: 4)
            .padding(.top, 13)
    }
}

private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
                y: 0
            )
        )
    }
}

private enum StepState {
    case completed
    case current
    case upcoming
}
