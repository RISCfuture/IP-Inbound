#!/bin/sh

# Skip macro fingerprint validation for Swift macros from packages
# This is needed because Xcode Cloud doesn't persist macro approvals between builds
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
