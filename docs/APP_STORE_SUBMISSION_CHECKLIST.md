# App Store Submission Checklist

Complete this checklist against the exact release commit and uploaded build. Do not store reviewer passwords or other credentials in this repository.

## Build and TestFlight

- [ ] Record the release commit SHA: `________________________`
- [ ] Archive that exact commit with the Release configuration.
- [ ] Upload the archive to App Store Connect and confirm processing completes.
- [ ] Select the processed build for the intended App Store version.
- [ ] Install the selected build from TestFlight on a physical iPhone.
- [ ] Smoke test launch and sign-in.
- [ ] Smoke test one focus session and app blocking.
- [ ] Smoke test one Health reward.
- [ ] Smoke test one photo-verification flow.
- [ ] Open the paywall and confirm Restore Purchases works.
- [ ] Confirm account deletion is reachable.

## Subscriptions

- [ ] Weekly and annual products have correct names, durations, localized prices, and availability.
- [ ] Subscription products are in the correct subscription group.
- [ ] Required subscription review screenshots and metadata are complete.
- [ ] Products are included with the submission when required.
- [ ] Purchase, pending/cancelled purchase, restore, expiration, and entitlement lapse have been tested.
- [ ] Paywall displays price, billing cadence, auto-renewal terms, Privacy Policy, Terms, and Restore Purchases.

## App Store Metadata

- [ ] App name, subtitle, description, keywords, categories, copyright, and version number are final.
- [ ] Description and screenshots accurately identify paid functionality.
- [ ] Screenshots represent the submitted build and required device sizes.
- [ ] Age-rating questionnaire is complete and consistent with app content.
- [ ] App Privacy answers match the release privacy report and actual data flows.
- [ ] Support URL opens publicly without login.
- [ ] Privacy Policy URL opens publicly without login.
- [ ] Terms URL opens publicly without login.
- [ ] Subscription-management URL works and does not improperly steer users to external purchasing.

## App Review Access and Notes

- [ ] Reviewer contact name, phone number, and email are current.
- [ ] A stable reviewer/demo account is available and will not expire during review.
- [ ] Reviewer credentials are stored only in App Store Connect, not GitHub.
- [ ] The reviewer can access paid functionality, or the notes provide a complete sandbox purchase/restore path.
- [ ] Review notes explain Family Controls authorization and shielding.
- [ ] Review notes explain HealthKit permission and Health-derived Aura rewards.
- [ ] Review notes explain AI-assisted photo verification and its consent flow.
- [ ] Review notes explain the Device Activity, Shield, widget, and Live Activity extensions.
- [ ] Review notes explain subscription purchase and Restore Purchases.
- [ ] Any non-obvious setup steps are documented clearly.
- [ ] A short reviewer walkthrough video is ready if the flow is difficult to reproduce.

## Final Submission

- [ ] Agreements, tax, banking, pricing, and availability are complete.
- [ ] Export-compliance questions are answered for the submitted build.
- [ ] Content-rights and trademark permissions are documented where applicable.
- [ ] The intended release option (manual, automatic, or phased) is selected.
- [ ] The correct build and all intended in-app purchases are included in the draft submission.
- [ ] A final teammate review confirms the metadata, build number, notes, and credentials.
- [ ] Submit for review only after every applicable item above is complete.
