//
//  File.swift
//  fx-cli
//
//  Created by fan xian on 2025/8/9.
//

import ArgumentParser
import Foundation

struct Append: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "append",
        abstract: "拼接图片（横向或竖向），保证输出 HEIC 格式"
    )

    @Argument(help: "需要拼接的图片路径（按顺序）")
    var images: [String]

    @Option(name: .shortAndLong, help: "拼接方向，可选 horizontal / vertical（默认 horizontal）")
    var direction: String = "horizontal"

    func run() throws {
        guard images.count >= 2 else {
            throw ValidationError("请至少提供两张图片")
        }

        let urls = images.map { URL(fileURLWithPath: $0) }
        let fm = FileManager.default
        for url in urls {
            guard fm.fileExists(atPath: url.path) else {
                throw ValidationError("文件不存在：\(url.path)")
            }
        }

        // 复用 Convert：先把非 HEIC 转换成 HEIC
        let heicURLs = try urls.map { try ensureHEICWithConvert(url: $0) }

        // 保存路径逻辑
        let saveDir = determineSaveDirectory(for: heicURLs)
        try fm.createDirectory(at: saveDir, withIntermediateDirectories: true)

        // 文件名拼接
        let fileName = heicURLs
            .map { $0.deletingPathExtension().lastPathComponent }
            .joined(separator: "_") + ".heic"
        let outputURL = saveDir.appendingPathComponent(fileName)

        // 拼接
        try appendImages(heicURLs, output: outputURL)

        print("✅ 拼接完成: \(outputURL.path)")
    }

    /// 调用已有 Convert 命令，将图片转为 HEIC
    func ensureHEICWithConvert(url: URL) throws -> URL {
        if url.pathExtension.lowercased() == "heic" {
            return url
        }
        // 这里直接用 Convert 的单文件转换逻辑
        var convertCmd = Convert()
        try convertCmd.convertToHEIC(url)  // 假设 Convert 里有这个函数并且是 public
        return url.deletingPathExtension().appendingPathExtension("heic")
    }

    func determineSaveDirectory(for urls: [URL]) -> URL {
        let parentDirs = Set(urls.map { $0.deletingLastPathComponent().path })
        if parentDirs.count == 1 {
            return urls.first!.deletingLastPathComponent()
        } else {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop")
        }
    }

    func appendImages(_ urls: [URL], output: URL) throws {
        let directionFlag = (direction.lowercased() == "vertical") ? "-append" : "+append"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/magick")
        process.arguments = ["convert"] + urls.map { $0.path } + [directionFlag, output.path]

        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw ValidationError("拼接失败")
        }
    }
}
