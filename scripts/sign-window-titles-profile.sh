#!/bin/sh
# Puts the window titles profile into the app's resources. When the app is being signed with a Developer ID, the
# profile is signed with that same certificate so System Settings shows it as verified; otherwise it is copied as is.
# Xcode runs this as the last build phase of the app target.
#
# When the profile gets signed
#
# Only a build that signs the app itself with a Developer ID signs the profile. Xcode's automatic signing archives
# the app with an "Apple Development" certificate and applies the Developer ID at export, after this phase has run,
# so an archive must use the Developer ID from the start to get a signed profile:
#
#     xcodebuild -workspace Amethyst.xcworkspace -scheme Amethyst -configuration Release archive \
#         -archivePath build/Amethyst.xcarchive DEVELOPMENT_TEAM=<team id> \
#         CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" -allowProvisioningUpdates
#
# Both settings are needed: with the identity alone, the Swift package targets stop the build with "conflicting
# provisioning settings". With fastlane, pass the same two settings through build_mac_app's xcargs. The export step
# afterwards re-signs the app with the same certificate and leaves the profile as it is.
#
# Every other build, including tests, continuous integration and development runs, gets the unsigned profile. It
# installs all the same; System Settings labels it unverified.
#
# How the certificate is found
#
# Xcode provides EXPANDED_CODE_SIGN_IDENTITY_NAME, the certificate's name ("-" or empty when the app is signed
# without one), and EXPANDED_CODE_SIGN_IDENTITY, its SHA-1 fingerprint. The signing tool selects a certificate by
# name or by subject key ID, and several certificates can share a name, so the fingerprint is mapped to the subject
# key ID through the keychain before signing.
set -eu

source="$SRCROOT/Amethyst/RevealWindowTitles.mobileconfig"
target="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/RevealWindowTitles.mobileconfig"
mkdir -p "$(dirname "$target")"

case "${EXPANDED_CODE_SIGN_IDENTITY_NAME:-}" in
    "Developer ID Application"*)
        ;;
    *)
        cp "$source" "$target"
        echo "note: window titles profile copied unsigned; the app is not being signed with a Developer ID"
        exit 0
        ;;
esac

key_id=$(security find-certificate -a -Z -p -c "$EXPANDED_CODE_SIGN_IDENTITY_NAME" \
    | awk -v wanted="$EXPANDED_CODE_SIGN_IDENTITY" '/SHA-1 hash:/ { keep = ($3 == wanted) } keep' \
    | openssl x509 -noout -ext subjectKeyIdentifier | tail -1 | tr -d ' :')
if [ -z "$key_id" ]; then
    echo "error: no certificate with fingerprint $EXPANDED_CODE_SIGN_IDENTITY in the keychain"
    exit 1
fi

security cms -S -Z "$key_id" -G -i "$source" -o "$target"
echo "note: window titles profile signed with $EXPANDED_CODE_SIGN_IDENTITY_NAME"
