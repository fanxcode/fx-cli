//
//  File.swift
//  fx-cli
//
//  Created by fan xian on 2025/8/9.
//

import ArgumentParser

struct Append: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "拼接图片"
    )

    func run() throws {
        print("拼接执行了")
    }
}
