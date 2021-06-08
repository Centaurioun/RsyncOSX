//
//  Logging.swift
//  rcloneosx
//
//  Created by Thomas Evensen on 20.11.2017.
//  Copyright © 2017 Thomas Evensen. All rights reserved.
//
// swiftlint:disable line_length

import Files
import Foundation

class Logfile: NamesandPaths {
    var outputprocess: OutputfromProcess?
    var log: String?
    var contentoflogfile: [String]?

    func writeloggfile() {
        if let atpath = fullpathmacserial {
            do {
                let folder = try Folder(path: atpath)
                let file = try folder.createFile(named: SharedReference.shared.logname)
                if let data = log {
                    try file.write(data)
                    filesize { [weak self] result in
                        switch result {
                        case let .success(size):
                            guard Int(truncating: size) < SharedReference.shared.logfilesize else {
                                let size = Int(truncating: size)
                                self?.error(errordescription: String(size), errortype: .logfilesize)
                                return
                            }
                        case let .failure(error):
                            self?.error(errordescription: error.localizedDescription, errortype: .readerror)
                        }
                    }
                }
            } catch let e {
                let error = e as NSError
                self.error(errordescription: error.localizedDescription, errortype: .writelogfile)
            }
        }
    }

    //  typealias HandlerNSNumber = (Result<NSNumber, Error>) -> Void
    func filesize(then handler: @escaping HandlerNSNumber) {
        if var atpath = fullpathmacserial {
            do {
                // check if file exists befor reading, if not bail out
                let fileexists = try Folder(path: atpath).containsFile(named: SharedReference.shared.logname)
                atpath += "/" + SharedReference.shared.logname
                if fileexists {
                    do {
                        // Return filesize
                        let file = try File(path: atpath).url
                        if let filesize = try FileManager.default.attributesOfItem(atPath: file.path)[FileAttributeKey.size] as? NSNumber {
                            handler(.success(filesize))
                        }
                    } catch {
                        handler(.failure(error))
                    }
                }
            } catch {
                handler(.failure(error))
            }
        }
    }

    func readloggfile() {
        if var atpath = fullpathmacserial {
            do {
                // check if file exists befor reading, if not bail out
                guard try Folder(path: atpath).containsFile(named: SharedReference.shared.logname) else { return }
                atpath += "/" + SharedReference.shared.logname
                let file = try File(path: atpath)
                log = try file.readAsString()
            } catch let e {
                let error = e as NSError
                self.error(errordescription: error.description, errortype: .emptylogfile)
            }
        }
    }

    private func minimumlogging() {
        let date = Date().localized_string_from_date()
        readloggfile()
        var tmplogg = [String]()
        var startindex = (outputprocess?.getOutput()?.count ?? 0) - 8
        if startindex < 0 { startindex = 0 }
        tmplogg.append("\n" + date + " -------------------------------------------" + "\n")
        for i in startindex ..< (outputprocess?.getOutput()?.count ?? 0) {
            tmplogg.append(outputprocess?.getOutput()?[i] ?? "")
        }
        if log == nil {
            log = tmplogg.joined(separator: "\n")
        } else {
            log! += tmplogg.joined(separator: "\n")
        }
        writeloggfile()
    }

    private func fulllogging() {
        let date = Date().localized_string_from_date()
        readloggfile()
        let tmplogg: String = "\n" + date + " -------------------------------------------" + "\n"
        if log == nil {
            log = tmplogg + (outputprocess?.getOutput() ?? [""]).joined(separator: "\n")
        } else {
            log! += tmplogg + (outputprocess?.getOutput() ?? [""]).joined(separator: "\n")
        }
        writeloggfile()
    }

    init(outputprocess: OutputfromProcess?) {
        super.init(.configurations)
        guard SharedReference.shared.fulllogging == true ||
            SharedReference.shared.minimumlogging == true
        else {
            return
        }
        self.outputprocess = outputprocess
        if SharedReference.shared.fulllogging {
            fulllogging()
        } else {
            minimumlogging()
        }
    }

    init(_ outputprocess: OutputfromProcess?, _ logging: Bool) {
        super.init(.configurations)
        if logging == false, outputprocess == nil {
            let date = Date().localized_string_from_date()
            log = date + ": " + "new logfile is created...\n"
            writeloggfile()
        } else {
            self.outputprocess = outputprocess
            fulllogging()
        }
    }

    init() {
        super.init(.configurations)
        readloggfile()
        contentoflogfile = [String]()
        if let log = self.log {
            contentoflogfile = log.components(separatedBy: .newlines)
        }
    }
}

extension Logfile: ViewOutputDetails {
    func reloadtable() {}

    func appendnow() -> Bool { return false }

    func getalloutput() -> [String] {
        return contentoflogfile ?? [""]
    }
}