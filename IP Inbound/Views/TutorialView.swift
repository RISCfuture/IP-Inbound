import SwiftUI

// swiftlint:disable accessibility_label_for_image

struct TutorialView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text("How to Use IP Inbound").font(.title)
                Text("""
                    IP Inbound is application that helps pilots fly an \
                    IP-to-target run to an accurate time on target. This \
                    application is useful for formation demo pilots, or pilots \
                    who participate in simulated tactical events, and need to be \
                    over a target at a precise time.
                    """)

                Text("Planning").font(.title2)

                ParagraphWithImage(imageName: "0-define-target", imageLeading: false) {
                    Text(AttributedString(localized: """
                        Start by defining your **target point (TP)**. This is the \
                        exact position you want to be over at **time on target \
                        (TOT)**. You can choose a target on the map or use \
                        latitude/longitude UTM coordinates. Tap the \
                        coordinates to change between coordinate types (DMS, \
                        DMM, DD, UTM).
                        """))
                }

                ParagraphWithImage(imageName: "1-define-ip", imageLeading: false) {
                    Text(AttributedString(localized: """
                        Next, define your **initial point (IP)**. This is the \
                        position where you will start your run-in to target. \
                        It’s used to help ensure you achieve your desired \
                        IP-to-target bearing with sufficient time to reach the \
                        TP by TOT.
                        """))

                    Text(AttributedString(localized: """
                        Choose a bearing and distance that satisfies your \
                        mission, and select a speed that gives you some wiggle \
                        room to speed up or slow down to meet your TOT. Mission \
                        requirements may dictate specific bearings, distance \
                        and/or speeds.
                        """))

                    Text(AttributedString(localized: """
                        IP Inbound will work the TOT backwards to find your time \
                        over IP, and it will provide guidance to ensure you \
                        reach the IP at or before that time.
                        """))
                }

                ParagraphWithImage(imageName: "2-tot", imageLeading: false) {
                    Text(AttributedString(localized: """
                        Finally, set your time on target. It’s ok if you don’t \
                        know your final TOT yet; you can adjust it in the air \
                        if necessary.
                        """))
                }

                Text("Pre-IP").font(.title2)

                ParagraphWithImage(imageName: "3-ground", imageLeading: false) {
                    Text(AttributedString(localized: """
                        When you’re on the ground, prior to takeoff, IP Inbound \
                        simply gives you a countdown timer so you can maintain \
                        awareness on your approaching TOT. The fun begins when \
                        you get airborne.
                        """))
                }

                ParagraphWithImage(imageName: "5-pre-ip", imageLeading: false) {
                    Text(AttributedString(localized: """
                        Once airborne, prior to reaching the IP, IP Inbound \
                        displays a **course deviation indicator (CDI)** \
                        providing **direct-to guidance** to your IP. The CDI is \
                        based on your ground track and magnetic heading. The \
                        title reads **P.POS → IP** to remind you that course \
                        guidance is to the IP, not the target.
                        """))

                    Text(AttributedString(localized: """
                        The **yellow arrow** points directly at the IP. The \
                        **red chevron** with an inset “T” indicates the \
                        direction to the target, for situational awareness. \
                        Below the CDI is the **speed deviation indication**, \
                        which indicates whether you need to slow down or speed \
                        up to make your time over IP.
                        """))

                    VStack {
                        HStack {
                            Image(systemName: "chevron.up.2").foregroundStyle(Color("TooSlowWarning"))
                                .padding(.horizontal, 4)
                            Text("Too slow")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .cornerRadius(8)

                        HStack {
                            Image(systemName: "chevron.up").foregroundStyle(Color("TooSlowCaution"))
                                .padding(.horizontal, 4)
                            Text("Slightly slow")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .cornerRadius(8)

                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color("OnTime"))
                                .padding(.horizontal, 4)
                            Text("On time")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .cornerRadius(8)

                        HStack {
                            Image(systemName: "chevron.down").foregroundStyle(Color("TooFastCaution"))
                                .padding(.horizontal, 4)
                            Text("Slightly fast")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .cornerRadius(8)

                        HStack {
                            Image(systemName: "chevron.down.2").foregroundStyle(Color("TooFastWarning"))
                                .padding(.horizontal, 4)
                            Text("Too fast")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .cornerRadius(12)

                    Text(AttributedString(localized: """
                         Your ground speed, the distance to the IP, and the TOT \
                        (_not_ time over IP) are shown at the bottom. Tap the \
                        TOT to toggle between local and Zulu time (GMT).
                        """))

                    Text(AttributedString(localized: """
                        Speed deviation is calculated factoring in turning \
                        required. IP Inbound assumes that you will make a level, \
                        45°-banked turn in the shortest direction to the IP when \
                        calculating time to IP.
                        """))

                    Text(AttributedString(localized: """
                        If your TOT changes at any point, either on the ground \
                        or in the air, simply press **‹ Time on Target** to \
                        return to the TOT page and set the new TOT. You can then \
                        return to the CDI view by pressing **Fly!** again.
                        """))
                }

                ParagraphWithImage(imageName: "4-pre-ip-early", imageLeading: false) {
                    Text(AttributedString(localized: """
                        If you are very early, IP Inbound assumes that you will \
                        want to hold over the IP until you reach your **push \
                        time**; in other words, the time you leave the IP for \
                        the target to make your TOT.
                        """))

                    Text(AttributedString(localized: """
                        In this situation, the speed deviation view will be \
                        replaced with a countdown timer to your push time. The \
                        speed deviation timer will show again when you are \
                        closer to your push time. Your push time is calculated \
                        by working backwards from TOT using the desired ground \
                        speed you set during IP configuration.
                        """))
                }

                Text("IP-to-Target Run").font(.title2)

                ParagraphWithImage(imageName: "6-ip-to-target", imageLeading: false) {
                    Text(AttributedString(localized: """
                        Any time you’ve passed the IP inbound, the CDI switches \
                        to target guidance. The **red arrow** points to the \
                        _desired track_ to the target (not direct-to the \
                        target). The **inset portion** of the arrow indicates how \
                        far left or right of the desired track you are. The \
                        **yellow chevron** with an inset “IP” indicates the \
                        direct course to the IP, for situational awareness.
                        """))

                    Text(AttributedString(localized: """
                        The speed deviation indicator now provides speed guidance \
                        to get you over the target at exactly the TOT. The title \
                        now reads **P.POS → Target**, as the CDI is now providing \
                        guidance to target.
                        """))
                }

                Text("Late to Target").font(.title2)

                ParagraphWithImage(imageName: "7-pre-ip-late", imageLeading: false) {
                    Text(AttributedString(localized: """
                        If IP Inbound calculates that you have insufficient time \
                        to fly to the IP and then the target, given your TOT, \
                        the CDI will change to providing guidance directly to \
                        the target. This is indicated by the title **P.POS → Target** \
                        showing in red. The CDI shows _desired track_ guidance to \
                        the target. The **red chevron** with an inset “T” is the \
                        direct course to the target, and the **yelow chevron** \
                        with an inset “IP” is the direct course to the IP.
                        """))
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 600) // Ideal for readability
            .frame(maxWidth: .infinity, alignment: .center) // Center on larger screens
        }.padding()
    }
}

struct ParagraphWithImage<Content: View>: View {
    let imageName: String
    let imageLeading: Bool
    let content: () -> Content

    @Environment(\.horizontalSizeClass)
    var sizeClass

    var body: some View {
        switch sizeClass {
            case .regular:
                HStack(alignment: .top, spacing: 8) {
                    if imageLeading {
                        image
                        VStack(alignment: .leading, spacing: 16) { content() }
                    } else {
                        VStack(alignment: .leading, spacing: 16) { content() }
                        image
                    }
                }
            case .compact, .none, .some:
                content()
                image
        }
    }

    private var image: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
    }

    init(imageName: String, imageLeading: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.imageName = imageName
        self.imageLeading = imageLeading
        self.content = content
    }
}

// swiftlint:enable accessibility_label_for_image

#Preview {
    TutorialView()
        .environment(\.colorScheme, .light)
}
