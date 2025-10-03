//
//  Convert.swift
//  fx-cli
//
//  Created by fan xian on 2025/8/9.
//

import ArgumentParser
import Foundation
// Files 未适配 Swift Concurrency。避免报错继续执行
@preconcurrency import Files
import Logging
import Rainbow
import ShellOut

struct Convert: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "将 JPG/JPEG/PNG/WEBP 图片转换为 HEIC 格式（支持目录递归和多线程处理）"
    )

    @Argument(help: "图片文件或文件夹路径")
    var path: String

    @Option(name: .shortAndLong, help: "并行任务数（默认 CPU 核心数）")
    var threads: Int?

    private var logger: Logger {
        Logger(label: "fx-photo.convert")
    }

    func run() throws {
        guard FileManager.default.fileExists(atPath: path) else {
            logger.error(Logger.Message(stringLiteral: "路径不存在: \(path)".red))
            throw ValidationError("路径不存在: \(path)".red)
        }

        if let folder = try? Folder(path: path) {
            let images = try collectImages(from: folder)
            if images.isEmpty {
                logger.warning(Logger.Message(stringLiteral: "没有找到可转换的图片".yellow))
                return
            }
            try convertImages(images, threadCount: threads ?? ProcessInfo.processInfo.processorCount)
            return
        }

        if let file = try? File(path: path) {
            logger.info(Logger.Message(stringLiteral: "开始转换 1 张图片".green))
            let start = Date()
            try convertToHEIC(file)
            logger.info(Logger.Message(stringLiteral: "转换完成 ✅ 用时 \(String(format: "%.2f", Date().timeIntervalSince(start))) 秒".green))
        }
    }

    private func convertImages(_ images: [File], threadCount: Int) throws {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = threadCount

        logger.info(Logger.Message(stringLiteral: "开始转换 \(images.count) 张图片，线程数: \(threadCount)".cyan))
        let start = Date()

        for img in images {
            queue.addOperation {
                do {
                    try self.convertToHEIC(img)
                    self.logger.info(Logger.Message(stringLiteral: "转换成功: \(img.path)".green))
                } catch {
                    self.logger.error(Logger.Message(stringLiteral: "转换失败: \(img.path)，错误: \(error.localizedDescription)".red))
                }
            }
        }

        queue.waitUntilAllOperationsAreFinished()
        logger.info(Logger.Message(stringLiteral: "全部转换完成 ✅ 用时 \(String(format: "%.2f", Date().timeIntervalSince(start))) 秒".green))
    }

    private func collectImages(from folder: Folder) throws -> [File] {
        let validExts = ["jpg", "jpeg", "png", "webp"]
        return folder.files.recursive.filter { file in
            file.extension.map { validExts.contains($0.lowercased()) } ?? false
        }
    }

    private func convertToHEIC(_ file: File) throws {
        let url = URL(fileURLWithPath: file.path)
        let heicUrl = url.deletingPathExtension().appendingPathExtension("heic")
        
        // 确保输出目录存在
        _ = try Folder(path: heicUrl.deletingLastPathComponent().path)
        
        let inputPath = "\"\(file.url.path)\""
        let outputPath = "\"\(heicUrl.path)\""
        
        try shellOut(to: "/usr/bin/sips", arguments: ["-s", "format", "heic", inputPath, "--out", outputPath])
        
        // 检查文件是否生成，再删除原文件
        if FileManager.default.fileExists(atPath: heicUrl.path) {
            try file.delete()
        } else {
            logger.error(Logger.Message(stringLiteral: "转换失败，未生成 HEIC: \(file.path)".red))
        }
    }
}
