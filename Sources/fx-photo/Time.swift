//
//  Time.swift
//  fx-cli
//
//  Created by fan xian on 2025/9/4.


import ArgumentParser
import Foundation
@preconcurrency import Files
import Logging
import Rainbow
import ShellOut

struct Time: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "time",
        abstract: "修改图片 EXIF 创建时间（支持目录，按文件名排序，每张图片时间依次 +1s）"
    )

    @Argument(help: "初始时间，格式：yyyy-MM-dd HH:mm:ss")
    var datetime: String

    @Argument(help: "图片文件或文件夹路径")
    var path: String

    private var logger: Logger {
        Logger(label: "fx-photo.time")
    }

    func run() throws {
        guard let baseDate = DateFormatter.cli.date(from: datetime) else {
            throw ValidationError("时间格式错误，请使用 yyyy-MM-dd HH:mm:ss".red)
        }

        guard FileManager.default.fileExists(atPath: path) else {
            logger.error(Logger.Message(stringLiteral: "路径不存在: \(path)".red))
            throw ValidationError("路径不存在: \(path)".red)
        }

        if let folder = try? Folder(path: path) {
            let images = try collectImages(from: folder)
            if images.isEmpty {
                logger.warning(Logger.Message(stringLiteral: "没有找到可修改的图片".yellow))
                return
            }
            try updateImages(images, baseDate: baseDate)
            return
        }

        if let file = try? File(path: path) {
            try updateExifTime(file: file, date: baseDate)
        }
    }

    // 递归收集支持的图片
    private func collectImages(from folder: Folder) throws -> [File] {
        let validExts = ["jpg", "jpeg", "png", "heic", "tiff"]
        return folder.files.recursive
            .filter { file in validExts.contains(file.extension?.lowercased() ?? "") }
            .sorted { $0.name < $1.name }
    }

    // 顺序更新每张图片的时间
    private func updateImages(_ images: [File], baseDate: Date) throws {
        var currentDate = baseDate
        let start = Date()
        logger.info(Logger.Message(stringLiteral: "开始修改 \(images.count) 张图片的 EXIF 时间".cyan))

        for (index, file) in images.enumerated() {
            try updateExifTime(file: file, date: currentDate)
            logger.info(Logger.Message(stringLiteral: "修改成功 (\(index + 1)/\(images.count)): \(file.name)".green))
            currentDate.addTimeInterval(1)
        }

        logger.info(Logger.Message(stringLiteral: "全部完成 ✅ 用时 \(String(format: "%.2f", Date().timeIntervalSince(start))) 秒".green))
    }

    // 调用 exiftool 修改 EXIF 时间（安全处理路径和空格）
    private func updateExifTime(file: File, date: Date) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateStr = formatter.string(from: date)

        let filePath = file.url.standardized.path
        let inputPath = "\"\(filePath)\""
        // 注意: 参数带空格必须加单引号
        let allDatesArg = "-AllDates='\(dateStr)'"

        try shellOut(
            to: "/opt/homebrew/bin/exiftool",
            arguments: ["-overwrite_original", allDatesArg, inputPath]
        )
    }
}

// MARK: - 日期格式工具
extension DateFormatter {
    static var cli: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }
}
