//
//  Convert.swift
//  fx-cli
//
//  Created by fan xian on 2025/8/9.
//

//
//  Convert.swift
//  fx-cli
//
//  Created by fan xian on 2025/8/9.
//

import ArgumentParser
import Foundation
import Files
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

    func run() throws {
        // 初始化日志
        var logger = Logger(label: "fx-photo.convert")
        logger.logLevel = .info

        // 检查路径是否存在
        guard let targetItem = try? Folder(path: path) ?? File(path: path) else {
            logger.error("路径不存在: \(path)".red)
            throw ValidationError("路径不存在: \(path)")
        }

        // 收集图片
        let images = collectImages(from: targetItem)
        if images.isEmpty {
            logger.warning("没有找到可转换的图片".yellow)
            return
        }

        let threadCount = threads ?? ProcessInfo.processInfo.processorCount
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = threadCount

        logger.info("开始转换 \(images.count) 张图片，线程数: \(threadCount)".green)

        let startTime = Date()

        for img in images {
            queue.addOperation {
                do {
                    try convertToHEIC(img)
                    logger.info("✅ 转换成功: \(img.path)".green)
                } catch {
                    logger.error("❌ 转换失败: \(img.path)\n  错误: \(error.localizedDescription)".red)
                }
            }
        }

        queue.waitUntilAllOperationsAreFinished()

        let elapsed = Date().timeIntervalSince(startTime)
        logger.info("全部转换完成 ✅ 用时 \(String(format: "%.2f", elapsed)) 秒".cyan)
    }

    // 递归收集所有图片文件
    func collectImages(from item: FileSystem.Item) -> [File] {
        var result: [File] = []
        let validExts = ["jpg", "jpeg", "png"]

        if let folder = item as? Folder {
            for file in folder.makeFileSequence(recursive: true, includeHidden: false) {
                if validExts.contains(file.extension?.lowercased() ?? "") {
                    result.append(file)
                }
            }
        } else if let file = item as? File,
                  validExts.contains(file.extension?.lowercased() ?? "") {
            result.append(file)
        }

        return result
    }

    // 用 ShellOut 调用 sips 转换
    func convertToHEIC(_ file: File) throws {
        let heicPath = file.path(dropExtension: true) + ".heic"
        do {
            try shellOut(to: "/usr/bin/sips",
                         arguments: ["-s", "format", "heic", file.path, "--out", heicPath])
        } catch let error as ShellOutError {
            throw ValidationError(error.message)
        }
    }
}
