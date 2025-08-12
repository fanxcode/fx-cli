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
        abstract: "将 JPG/JPEG/PNG 图片转换为 HEIC 格式（支持目录递归和多线程处理）"
    )

    @Argument(help: "图片文件或文件夹路径")
    var path: String

    @Option(name: .shortAndLong, help: "并行任务数（默认 CPU 核心数）")
    var threads: Int?

    private var logger: Logger {
        Logger(label: "fx-photo.convert")
    }

    func run() throws {
        let targetFolder = try? Folder(path: path)
        let targetFile = try? File(path: path)

        if let folder = targetFolder {
            let images = try collectImages(from: folder)
            if images.isEmpty {
                logger.warning(Logger.Message(stringLiteral: "没有找到可转换的图片".yellow))
                return
            }
            try convertImages(images, threadCount: threads ?? ProcessInfo.processInfo.processorCount)
        } else if let file = targetFile {
            logger.info(Logger.Message(stringLiteral: "开始转换 1 张图片".green))
            let start = Date()
            try convertToHEIC(file)
            logger.info(Logger.Message(stringLiteral: "转换完成 ✅ 用时 \(String(format: "%.2f", Date().timeIntervalSince(start))) 秒".green))
        } else {
            throw ValidationError("路径不存在: \(path)".red)
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
        let validExts = ["jpg", "jpeg", "png"]
        return folder.files.recursive.filter { file in
            file.extension.map { validExts.contains($0.lowercased()) } ?? false
        }
    }

    private func convertToHEIC(_ file: File) throws {
        let url = URL(fileURLWithPath: file.path)
        let heicUrl = url.deletingPathExtension().appendingPathExtension("heic")
        let heicPath = heicUrl.path
        _ = try Folder(path: heicUrl.deletingLastPathComponent().path)

        try shellOut(to: "/usr/bin/sips",
                     arguments: ["-s", "format", "heic", file.path, "--out", heicPath])
        try file.delete()
    }
}
