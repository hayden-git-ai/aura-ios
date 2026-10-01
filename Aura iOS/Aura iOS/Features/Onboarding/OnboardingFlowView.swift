//
//  OnboardingFlowView.swift
//  Aura iOS
//
//  Container for the onboarding funnel. Switches on the current step and slides
//  between them. Each screen owns its own background.
//

import SwiftUI

struct OnboardingFlowView: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        Group {
            switch flow.step {
            case .welcome:  OnbWelcomeView()
            case .meet:     OnbMeetView()
            case .name:     OnbNameView()
            case .age:      OnbAgeView()
            case .handoff:  OnbHandoffView()
            case .chat:     OnbDiagnosisChat()
            case .loopDemo: OnbLoopDemoView()
            case .demoFreeze:
                OnbDemoScreen(showBack: false,
                              title: "Block Distracting Apps",
                              subtext: "To get them back you need to spend Aura Coins.",
                              cta: "Next")
            case .demoEarn:
                OnbDemoScreen(showBack: false,
                              title: "Earn Aura Coins",
                              subtext: "There are 30+ unique ways to earn Aura Coins & you can even create your own!",
                              cta: "Next")
            case .demoSpend:
                OnbDemoScreen(showBack: false,
                              title: "Buy Screen Time",
                              subtext: "Use Aura Coins to purchase screen time and use the apps you blocked.",
                              cta: "Continue")
            case .reframe:  OnbReframeView()
            case .bridge:   OnbBridgeView()

            case .qGoal:
                OnbSingleSelectScreen(showBack: false, progress: 0.34, question: "what is your goal with Aura?",
                                      options: OnbQ.goal, key: \.goal,
                                      reaction: { answer in
                                          switch answer {
                                          case "Improve focus":             return "bold goal for someone holding a phone. i respect it."
                                          case "Reduce mindless scrolling": return "good, less scrolling. your thumb's been doing cardio for months."
                                          case "Sleep better":              return "yep, your 2am scrolling sessions are so cancelled."
                                          case "Be more present":           return "oh man, your phone's going to feel so left out."
                                          case "Be more productive":        return "more done, less doomscrolling. groundbreaking, i know."
                                          case "Just curious":              return "that's what everyone says before they stay."
                                          default:                          return ""
                                          }
                                      })
            case .qSlider:  OnbScrollSliderView()
            case .qFeelings:
                OnbMultiSelectScreen(progress: 0.42, question: "how does your screen time affect you the most?",
                                     options: OnbQ.feelings, key: \.feelings,
                                     reaction: { picks in
                                         if picks.count > 1 { return "a whole starter pack of side effects. classic." }
                                         switch picks.first {
                                         case "No focus / procrastination":     return "ah, the art of being busy doing nothing."
                                         case "Anxiety / overstimulation":       return "wired and fried. the phone did that. so rude."
                                         case "Bad sleep":                       return "yeah, I'd blame the little glowing rectangle."
                                         case "Productivity loss":               return "your to-do list must have trust issues now."
                                         case "I feel mentally fried":           return "that's the phone slow-cooking your attention span."
                                         case "Less time with friends / family": return "your group chat is thriving. the group dinner, not so much."
                                         default:                                return ""
                                         }
                                     })
            case .qPersona:
                OnbSingleSelectScreen(progress: 0.48, question: "what best describes you?",
                                      options: OnbQ.persona, key: \.persona,
                                      reaction: { answer in
                                          switch answer {
                                          case "Student":                    return "the syllabus said 'readings.' it did not mean the comments section."
                                          case "Working professional":       return "work-life balance achieved: you're distracted at both."
                                          case "Entrepreneur / Self-employed": return "ceo, cfo, and unfortunately head of doomscrolling."
                                          case "Parent / Caregiver":         return "teaching them not to be on screens. from behind a screen. bold."
                                          case "Currently between jobs":     return "your calendar is empty and your screen time is fully booked."
                                          case "Other":                      return "whatever you do, you clearly do it near a phone."
                                          default:                           return ""
                                          }
                                      })
            case .qWorstTime:
                OnbSingleSelectScreen(progress: 0.54, question: "when do you usually scroll the most?",
                                      options: OnbQ.worstTime, key: \.worstTime,
                                      reaction: { answer in
                                          switch answer {
                                          case "First thing in the morning": return "morning person? no. morning scroller? absolutely."
                                          case "During the day":             return "prime hours, handed to your phone. bold scheduling."
                                          case "Evenings":                   return "the wind-down that winds you up. classic."
                                          case "Honestly, all day":          return "all day, huh. basically a second full-time job."
                                          case "Not sure":                   return "no idea? that's usually a sign it's a lot."
                                          default:                           return ""
                                          }
                                      })
            case .qSkip:
                OnbMultiSelectScreen(progress: 0.60, question: "what would you like to prioritize over scrolling?",
                                     options: OnbQ.skip, key: \.skips,
                                     reaction: { picks in
                                         if picks.count > 1 { return "ambitious. i like it." }
                                         switch picks.first {
                                         case "Sleep":                            return "the elite tier of self-care. good pick."
                                         case "The gym":                          return "good, your membership's been very lonely."
                                         case "Work or study":                    return "work over scrolling. your to-do list just gasped."
                                         case "Time with people":                 return "people over posts. revolutionary stuff."
                                         case "Getting outside":                  return "the grass is still out there, apparently. go check."
                                         case "Something you'd promised yourself": return "that thing you said you'd 'start monday.' it's monday somewhere."
                                         default:                                 return ""
                                         }
                                     })
            case .qDoomProfile: OnbDoomProfileView()
            case .qReviewDrop:  OnbReviewDropView()
            case .qTried:
                // Single-select; the ref-B "here's why" reveal is the reaction, so
                // no inline reaction here. Skip the reveal only for "No, first time".
                OnbSingleSelectScreen(progress: 0.66, question: "have you tried to reduce your screen time before?",
                                      options: OnbQ.tried, key: \.triedBefore,
                                      reaction: { answer in
                                          switch answer {
                                          case "Yes, didn't stick":   return "didn't stick, because 'just use it less' isn't a plan. we've got one."
                                          case "Yes, briefly worked": return "a good start that fizzled. happens. we'll make it last this time."
                                          case "No, first time":      return "never tried before? then you've got beginner's luck on your side."
                                          default:                    return ""
                                          }
                                      })
            case .qWhyFlopped: OnbWhyFloppedView()
            case .qReclaim:    OnbReclaimView()
            case .qHabits:     OnbHabitPickView()
            case .qExercises:  OnbExercisePickView()
            case .qDailyGoal:  OnbDailyGoalView()
            case .qLoading:    OnbLoadingView()
            case .qCustomPlan: OnbCustomPlanView()
            case .qScience:    OnbScienceView()
            case .qReviews:    OnbReviewsView()
            case .qCommit:     OnbCommitView()
            }
        }
        .preferredColorScheme(statusBarColorScheme)
        .id(flow.step)
        .onAppear { flow.appear() }
    }

    private var statusBarColorScheme: ColorScheme {
        switch flow.step {
        case .welcome, .meet, .name, .age, .handoff, .loopDemo:
            // These full-flow previews use the mountain/companion artwork.
            return .dark
        default:
            return .light
        }
    }
}
