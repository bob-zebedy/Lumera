import SwiftUI

extension CameraView {

    func coachAllows(_ mark: CoachMark) -> Bool {
        guard showCoach else { return true }
        guard coachIndex < coachSteps.count else { return true }
        return coachSteps[coachIndex].mark == mark
    }

    func advanceCoach(matching mark: CoachMark) {
        guard showCoach,
              coachIndex < coachSteps.count,
              coachSteps[coachIndex].mark == mark else { return }
        advanceCoachStep()
    }

    func advanceCoachStep() {
        guard showCoach else { return }
        var next = coachIndex + 1

        while next < coachSteps.count, shouldSkipCoachStep(coachSteps[next].mark) {
            next += 1
        }
        if next < coachSteps.count {
            withAnimation(.easeInOut(duration: 0.25)) {
                coachIndex = next
            }
        } else {
            finishCoach()
        }
    }

    private func shouldSkipCoachStep(_ mark: CoachMark) -> Bool {
        switch mark {
        case .previewClose: return !coachDidOpenPreview
        default: return false
        }
    }

    func startCoach() {
        coachInitialHDR = model.settings.useComputationalPhotography
        coachInitialThumbnail = model.lastThumbnail
        coachInitialEV = model.exposureBias
        coachIndex = 0
        coachDidOpenPreview = false

        if showPanel {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                showPanel = false
            }
        }
        showCoach = true
    }

    func finishCoach() {
        withAnimation(.easeOut(duration: 0.2)) {
            showCoach = false
        }
        model.settings.hasShownOnboarding = true
        let defaultLens = model.settings.defaultLens
        let defaultFormat = model.settings.defaultFormat
        let defaultFlash = model.settings.defaultFlashMode
        let panelDefault = model.settings.panelExpandedAtLaunch
        let hdrSnapshot = coachInitialHDR
        let evSnapshot = coachInitialEV

        model.lastThumbnail = coachInitialThumbnail
        Task {
            if model.exposureBias != evSnapshot {
                model.exposureBias = evSnapshot
                await model.applyExposureBias()
            }
        }
        Task {
            if model.flashMode != defaultFlash {
                await model.setFlashMode(defaultFlash)
            }
            if model.currentFormat != defaultFormat {
                await model.setFormat(defaultFormat)
            }
            if model.currentLens != defaultLens, model.availableLenses.contains(defaultLens) {
                await model.selectLens(defaultLens)
            }
            if model.settings.useComputationalPhotography != hdrSnapshot {
                model.settings.useComputationalPhotography = hdrSnapshot
                await model.applySettings()
            }
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            showPanel = panelDefault
        }
    }
}
