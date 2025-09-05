//
//  Time.swift
//  fx-cli
//
//  Created by fan xian on 2025/9/4.
//

import ArgumentParser
import Foundation
import Files
import Logging
import ImageIO

struct Time: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "time",
        abstract: "修改图片的 EXIF 创建时间，支持文件夹顺序递增"
    )

    @Argument(help: "初始时间，格式：yyyy-MM-dd HH:mm:ss")
    var datetime: String

    @Argument(help: "图片文件或文件夹路径")
    var path: String

    @Option(name: .shortAndLong, help: "时间递增步长（秒），默认为 1 秒")
    var step: Int = 1

    func run() throws {
        let logger = Logger(label: "fx-photo-time")

        // 解析初始时间
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let baseDate = formatter.date(from: datetime) else {
            throw ValidationError("时间格式错误，请使用 \"yyyy-MM-dd HH:mm:ss\"")
        }

        var currentDate = baseDate

        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            // 文件夹
            let folder = try Folder(path: path)
            let files = folder.files
                .filter { isSupported(file: $0) }
                .sorted { lhs, rhs in
                    let (base1, num1) = splitName(lhs.nameExcludingExtension)
                    let (base2, num2) = splitName(rhs.nameExcludingExtension)

                    if base1 == base2 {
                        return num1 < num2
                    } else {
                        return base1 < base2
                    }
                }

            for file in files {
                try updateExif(for: file, at: currentDate, logger: logger)
                currentDate = currentDate.addingTimeInterval(TimeInterval(step))
            }
        } else {
            // 单个文件
            let file = try File(path: path)
            try updateExif(for: file, at: currentDate, logger: logger)
        }
    }
}

// MARK: - EXIF 修改
private func updateExif(for file: File, at date: Date, logger: Logger) throws {
    let url = URL(fileURLWithPath: file.path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let type = CGImageSourceGetType(source) else {
        logger.error("无法读取文件: \(file.name)")
        return
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let dateString = formatter.string(from: date)

    let metadata = [
        kCGImagePropertyExifDictionary as String: [
            kCGImagePropertyExifDateTimeOriginal as String: dateString,
            kCGImagePropertyExifDateTimeDigitized as String: dateString
        ],
        kCGImagePropertyTIFFDictionary as String: [
            kCGImagePropertyTIFFDateTime as String: dateString
        ]
    ] as CFDictionary

    let destData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(destData, type, 1, nil) else {
        logger.error("无法创建目标文件: \(file.name)")
        return
    }

    CGImageDestinationAddImageFromSource(destination, source, 0, metadata)
    guard CGImageDestinationFinalize(destination) else {
        logger.error("保存文件失败: \(file.name)")
        return
    }

    try destData.write(to: url)
    logger.info("已更新 \(file.name) 时间为 \(dateString)")
}

// MARK: - 工具函数
private func isSupported(file: File) -> Bool {
    let ext = file.extension?.lowercased() ?? ""
    return ["jpg", "jpeg", "png", "heic"].contains(ext)
}

/// 拆分文件名 -> (基础名, 数字后缀)，没有数字时 num = 0
private func splitName(_ name: String) -> (String, Int) {
    let pattern = #"^(.*?)(?:-(\d+))?$"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) {
        let baseRange = Range(match.range(at: 1), in: name)!
        let base = String(name[baseRange])
        if let numRange = Range(match.range(at: 2), in: name),
           let num = Int(name[numRange]) {
            return (base, num)
        }
        return (base, 0)
    }
    return (name, 0)
}
