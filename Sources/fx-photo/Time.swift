//
//  Time.swift
//  fx-cli
//
//  Created by fan xian on 2025/9/4.
//

import ArgumentParser
import Foundation
// Files 未适配 Swift Concurrency。避免报错继续执行
@preconcurrency import Files
import Logging
import Rainbow
import ShellOut

struct Time: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "time",
        abstract: "修改文件或目录下 Apple Photos 支持的图片/视频的时间戳"
    )

    @Argument(help: "目标时间，例如 \"2020-02-02 12:00:00\"")
    var datetime: String

    @Argument(help: "目标文件或目录路径")
    var path: String

    func run() throws {
        let logger = Logger(label: "fx-cli.time")

        // 转换时间格式为 `touch -t` 需要的格式
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = formatter.date(from: datetime) else {
            throw ValidationError("时间格式错误，请使用 \"yyyy-MM-dd HH:mm:ss\"")
        }

        let touchFormatter = DateFormatter()
        touchFormatter.dateFormat = "yyyyMMddHHmm.ss"
        touchFormatter.locale = Locale(identifier: "en_US_POSIX")
        let touchString = touchFormatter.string(from: date)

        // 判断是文件还是目录
        if FileManager.default.fileExists(atPath: path) {
            if let file = try? File(path: path) {
                // 单个文件
                if isSupported(file: file) {
                    try updateTime(for: file.path, timeString: touchString, logger: logger)
                } else {
                    logger.warning("\("跳过不支持的文件:".yellow) \(file.path)")
                }
            } else if let folder = try? Folder(path: path) {
                // 遍历目录（递归）
                for file in folder.files.recursive {
                    if isSupported(file: file) {
                        try updateTime(for: file.path, timeString: touchString, logger: logger)
                    } else {
                        logger.debug("跳过: \(file.path)")
                    }
                }
            } else {
                throw ValidationError("路径无效: \(path)")
            }
        } else {
            throw ValidationError("路径不存在: \(path)")
        }
    }

    /// 判断是否是 Apple Photos 支持的图片/视频
    private func isSupported(file: File) -> Bool {
        let supportedExtensions: Set<String> = [
            "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "bmp",
            "mov", "mp4", "m4v"
        ]
        return supportedExtensions.contains(file.extension?.lowercased() ?? "")
    }

    private func updateTime(for filePath: String, timeString: String, logger: Logger) throws {
        let command = "touch -t \(timeString) \"\(filePath)\""
        try shellOut(to: command)
        logger.info("\("✅ 修改完成:".green) \(filePath)")
    }
}
