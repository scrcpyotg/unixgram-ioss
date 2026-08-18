import SwiftUI

struct UnixgramAllPagesHubView: View {
    var body: some View {
        List {
            Section("Основные страницы") {
                NavigationLink("Лента") { UnixgramAllRealFeedView() }
                NavigationLink("Обзор / сообщества") { UnixgramAllRealDiscoverView() }
                NavigationLink("Уведомления") { UnixgramAllRealNotificationsView() }
                NavigationLink("Сообщения") { UnixgramRealMessagesView() }
                NavigationLink("Студия автора") { UnixgramAllRealCreatorStudioView() }
                NavigationLink("Профиль и настройки") { UnixgramRealProfileView() }
            }

            Section("Музыка") {
                NavigationLink {
                    SoundCloudNativeView()
                } label: {
                    Label("SoundCloud", systemImage: "waveform")
                }
            }

            Section("Дополнительные страницы") {
                NavigationLink("Stories") { UnixgramAllRealStoriesView() }
                NavigationLink("Stars / подарки") { UnixgramAllRealStarsView() }
                NavigationLink("Premium") { UnixgramAllRealPremiumView() }
                NavigationLink("Сообщества") { UnixgramRealCommunitiesView() }
            }
        }
        .navigationTitle("Все страницы")
        .scrollContentBackground(.hidden)
        .background(Color.black)
    }
}
