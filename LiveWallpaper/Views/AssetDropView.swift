import SwiftUI
import AVKit

struct AssetDropView: View {
    @State private var videoURL: URL?
    @State private var player: AVPlayer?
    @State var video:WallpaperAsset?
    @State private var showToast = false
    
    var body: some View {
        ZStack {
            
            if player == nil {
                DropZoneView(onDrop: { url in
                    loadVideo(from: url)
                }, onSelect: {
                    selectVideoFile()
                })
            } else {
                VStack {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                        .cornerRadius(10)
                        .padding()
                    
                    Button("Set as Wallpaper", action: {
                        player?.pause()
                        WallpaperManager.shared.setWallpaperVideo(video: video!)
                        UserSetting.shared.setVideo(video!)
                        video = nil
                        player = nil
                        toast()
                    })
                    .opacity(video != nil ? 1.0 : 0.0)
                    .buttonStyle(.borderedProminent)
                    .padding()
                    
                }
            }
            
            if showToast {
                Toast(systemImage: "checkmark.circle.fill", message: "Wallpaper Set", isVisible: $showToast)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        
    }
    
    private func toast() {
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
    
    private func loadVideo(from url: URL) {
        videoURL = url
        player = AVPlayer(url: url)
        player?.play()
        
        let id = UUID().uuidString
        
        Task {
            do {
                let copiedFileURL = try await copyFile(fileURL: url, targetFilename: id)
                guard let thumbnailPath = await generateThumbnailAndSave(from: copiedFileURL.path(percentEncoded: false), fileName: "\(id).png") else {return}
                let attrs = await analyzeVideoCharacteristics(url: url) ?? .default
                video = WallpaperAsset(id: id, url: copiedFileURL.path(percentEncoded: false), type: .video(attrs), thumbnail: thumbnailPath, createdAt: Date())
            } catch {
                print("Error copying file: \(error)")
            }
        }
        
    }
    
    private func selectVideoFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = AppConstant.supportMediaType
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.urls.first {
            loadVideo(from: url)
        }
    }
}

struct DropZoneView: View {
    var onDrop: (URL) -> Void
    var onSelect: () -> Void
    
    
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5]))
            .background(Color.gray.opacity(0.2))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                VStack {
                    Text("Drag & Drop your video here\nor Click to select")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.title3)
                    Text(".mp4, .mov supported")
                        .padding(4)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
            .onDrop(of: AppConstant.supportMediaType, isTargeted: nil) { providers in
                guard let provider = providers.first(where: isSupportMediaType) else {
                    return false  // Reject non-MP4 files
                }
                provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { (item, error) in
                    if let url = item as? URL {
                        onDrop(url)
                    }
                }
                return true  // Accept the drop
            }
    }

    private func isSupportMediaType(_ item: NSItemProvider) -> Bool {
        return AppConstant.supportMediaType.contains { item.hasItemConformingToTypeIdentifier($0.identifier) }
    }

}

struct AssetDropView_Previews: PreviewProvider {
    static var previews: some View {
        AssetDropView(video: nil)
    }
}
