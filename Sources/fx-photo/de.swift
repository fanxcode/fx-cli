//
//  File.swift
//  fx-cli
//
//  Created by fan xian on 2025/8/9.
//

import ArgumentParser
import Foundation

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
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default

        guard fm.fileExists(atPath: url.path) else {
            throw ValidationError("路径不存在：\(path)")
        }

        // 获取所有需要处理的文件
        let images = try collectImages(from: url)
        if images.isEmpty {
            print("没有找到可转换的图片")
            return
        }

        let threadCount = threads ?? ProcessInfo.processInfo.processorCount
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = threadCount

        print("开始转换 \(images.count) 张图片，线程数：\(threadCount)")

        let startTime = Date()

        for img in images {
            queue.addOperation {
                self.convertToHEIC(img)
            }
        }

        queue.waitUntilAllOperationsAreFinished()

        let elapsed = Date().timeIntervalSince(startTime)
        print("全部转换完成 ✅ 用时 \(String(format: "%.2f", elapsed)) 秒")
    }

    // 递归收集所有图片文件
    func collectImages(from url: URL) throws -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default

        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil)
                while let file = enumerator?.nextObject() as? URL {
                    if ["jpg", "jpeg", "png"].contains(file.pathExtension.lowercased()) {
                        result.append(file)
                    }
                }
            } else if ["jpg", "jpeg", "png"].contains(url.pathExtension.lowercased()) {
                result.append(url)
            }
        }
        return result
    }

    // 调用 sips 转换
    func convertToHEIC(_ url: URL) throws {
        let heicURL = url.deletingPathExtension().appendingPathExtension("heic")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = ["-s", "format", "heic", url.path, "--out", heicURL.path]

        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                print("✅ 转换成功: \(heicURL.path)")
            } else {
                let err = String(
                    data: pipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? "未知错误"
                throw ValidationError("❌ 转换失败: \(url.path)\n  错误: \(err)")
            }
        } catch {
            throw ValidationError("❌ 无法运行 sips: \(error.localizedDescription)")
        }
    }
}
