// Logging.swift
// Shared OSLog loggers for every pipeline stage.
// Visible in Console.app (filter by subsystem "com.dialkit") and in the terminal via swift run.

import OSLog

enum Log {
    static let device     = Logger(subsystem: "com.dialkit", category: "device")
    static let input      = Logger(subsystem: "com.dialkit", category: "input")
    static let router     = Logger(subsystem: "com.dialkit", category: "router")
    static let overlay    = Logger(subsystem: "com.dialkit", category: "overlay")
    static let haptics    = Logger(subsystem: "com.dialkit", category: "haptics")
    static let config     = Logger(subsystem: "com.dialkit", category: "config")
    static let shortcut   = Logger(subsystem: "com.dialkit", category: "shortcut")
    static let volume     = Logger(subsystem: "com.dialkit", category: "volume")
    static let appwatcher = Logger(subsystem: "com.dialkit", category: "appwatcher")
}
