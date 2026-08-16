import SwiftUI

struct StoriesExperienceView: View {
    @State private var stories = UGMockData.stories
    @State private var selectedStory: UGStory?
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Истории")
                        .font(.system(size: 32, weight: .bold))
                    Spacer()
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(Circle())
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        addStoryCard

                        ForEach(stories) { story in
                            Button {
                                selectedStory = story
                            } label: {
                                VStack(spacing: 7) {
                                    Circle()
                                        .stroke(
                                            story.viewed
                                            ? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
                                            : LinearGradient(colors: [.green, .cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            lineWidth: 4
                                        )
                                        .frame(width: 72, height: 72)
                                        .overlay {
                                            Circle()
                                                .fill(storyGradient(story.gradientIndex))
                                                .padding(5)
                                        }

                                    Text(story.author)
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .frame(width: 78)
                                }
                            }
                        }
                    }
                }

                Text("Недавние")
                    .font(.system(size: 22, weight: .bold))

                ForEach(stories) { story in
                    Button {
                        selectedStory = story
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(storyGradient(story.gradientIndex))
                                .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(story.author)
                                    .font(.system(size: 18, weight: .bold))
                                Text(story.caption)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(story.postedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color.white.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
            .padding(20)
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedStory) { story in
            StoryViewer(story: story)
        }
        .sheet(isPresented: $showingEditor) {
            StoryEditorView()
                .presentationDetents([.large])
                .presentationCornerRadius(30)
        }
    }

    private var addStoryCard: some View {
        Button {
            showingEditor = true
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 72, height: 72)
                        .overlay(Image(systemName: "scribble.variable").font(.title2))

                    Circle()
                        .fill(.purple)
                        .frame(width: 24, height: 24)
                        .overlay(Image(systemName: "plus").font(.caption.bold()))
                }
                Text("Моя")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
        }
    }

    private func storyGradient(_ index: Int) -> LinearGradient {
        let palettes: [[Color]] = [
            [.indigo, .purple, .pink],
            [.cyan, .blue, .indigo],
            [.orange, .pink, .purple]
        ]
        let colors = palettes[index % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct StoryViewer: View {
    let story: UGStory
    @Environment(\.dismiss) private var dismiss
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 3)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.white)
                                .frame(width: geo.size.width * progress, height: 3)
                        }
                }
                .frame(height: 3)

                HStack(spacing: 10) {
                    Circle().fill(.white.opacity(0.15)).frame(width: 38, height: 38)
                    VStack(alignment: .leading) {
                        Text(story.author).font(.headline)
                        Text(story.username).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.title3.bold())
                    }
                }
                .padding(.top, 10)

                Spacer()

                Text(story.caption)
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer()

                HStack {
                    TextField("Ответить…", text: .constant(""))
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())

                    Image(systemName: "heart")
                        .font(.title2)
                    Image(systemName: "paperplane")
                        .font(.title2)
                }
            }
            .padding(16)
        }
        .foregroundStyle(.white)
        .task {
            withAnimation(.linear(duration: 7)) {
                progress = 1
            }
            try? await Task.sleep(for: .seconds(7))
            dismiss()
        }
    }
}

private struct StoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var selectedTool = 0

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button("Отмена") { dismiss() }
                    .foregroundStyle(.white)
                Spacer()
                Text("Новая история")
                    .font(.headline)
                Spacer()
                Button("Готово") { dismiss() }
                    .fontWeight(.bold)
                    .foregroundStyle(.cyan)
            }

            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [.indigo, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    Text(caption.isEmpty ? "Ваша история" : caption)
                        .font(.system(size: 30, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(24)
                }

            HStack(spacing: 26) {
                editorTool("textformat", "Текст", 0)
                editorTool("paintbrush", "Рисовать", 1)
                editorTool("music.note", "Музыка", 2)
                editorTool("face.smiling", "Эмодзи", 3)
            }

            TextField("Подпись", text: $caption)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(18)
        .background(Color.black)
        .foregroundStyle(.white)
    }

    private func editorTool(_ icon: String, _ title: String, _ index: Int) -> some View {
        Button {
            selectedTool = index
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 21))
                    .frame(width: 44, height: 44)
                    .background(selectedTool == index ? Color.white : Color.white.opacity(0.06))
                    .foregroundStyle(selectedTool == index ? .black : .white)
                    .clipShape(Circle())
                Text(title).font(.caption2)
            }
        }
    }
}
