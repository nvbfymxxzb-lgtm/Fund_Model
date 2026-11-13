import Foundation

/// A small DEFLATE (RFC 1951) decoder, used to open compressed MusicXML (.mxl) files without outside libraries.
enum Inflate {
    struct Failure: Error { let reason: String }

    struct Huffman {
        var counts = [Int](repeating: 0, count: 16)
        var symbols: [Int]

        init(lengths: [Int]) {
            symbols = [Int](repeating: 0, count: lengths.count)
            for l in lengths { counts[l] += 1 }
            counts[0] = 0
            var offsets = [Int](repeating: 0, count: 16)
            for i in 1..<16 { offsets[i] = offsets[i - 1] + counts[i - 1] }
            for (sym, l) in lengths.enumerated() where l != 0 {
                symbols[offsets[l]] = sym
                offsets[l] += 1
            }
        }
    }

    struct Reader {
        let bytes: [UInt8]
        var pos = 0
        var bitBuffer: UInt32 = 0
        var bitCount = 0

        mutating func bits(_ need: Int) throws -> Int {
            var value = bitBuffer
            while bitCount < need {
                guard pos < bytes.count else { throw Failure(reason: "unexpected end of data") }
                value |= UInt32(bytes[pos]) << UInt32(bitCount)
                pos += 1
                bitCount += 8
            }
            bitBuffer = need == 32 ? 0 : value >> UInt32(need)
            bitCount -= need
            return Int(value & ((1 << UInt32(need)) - 1))
        }

        mutating func decode(_ h: Huffman) throws -> Int {
            var code = 0, first = 0, index = 0
            for len in 1..<16 {
                code |= try bits(1)
                let count = h.counts[len]
                if code - count < first { return h.symbols[index + (code - first)] }
                index += count
                first += count
                first <<= 1
                code <<= 1
            }
            throw Failure(reason: "bad Huffman code")
        }
    }

    static let lengthBase = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    static let lengthExtra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
    static let distBase = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
    static let distExtra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]

    static func decompress(_ input: [UInt8], limit: Int) throws -> [UInt8] {
        var r = Reader(bytes: input)
        var out: [UInt8] = []
        out.reserveCapacity(min(limit, input.count * 4))
        var last = false
        while !last {
            last = try r.bits(1) == 1
            let type = try r.bits(2)
            switch type {
            case 0:
                r.bitBuffer = 0; r.bitCount = 0
                guard r.pos + 4 <= input.count else { throw Failure(reason: "truncated stored block") }
                let len = Int(input[r.pos]) | Int(input[r.pos + 1]) << 8
                r.pos += 4
                guard r.pos + len <= input.count, out.count + len <= limit else { throw Failure(reason: "stored block too large") }
                out.append(contentsOf: input[r.pos..<(r.pos + len)])
                r.pos += len
            case 1, 2:
                var lenCode: Huffman, distCode: Huffman
                if type == 1 {
                    var l = [Int](repeating: 8, count: 288)
                    for i in 144..<256 { l[i] = 9 }
                    for i in 256..<280 { l[i] = 7 }
                    lenCode = Huffman(lengths: l)
                    distCode = Huffman(lengths: [Int](repeating: 5, count: 30))
                } else {
                    let nlen = try r.bits(5) + 257, ndist = try r.bits(5) + 1, ncode = try r.bits(4) + 4
                    guard nlen <= 286, ndist <= 30 else { throw Failure(reason: "bad block header") }
                    let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
                    var lengths = [Int](repeating: 0, count: 19)
                    for i in 0..<ncode { lengths[order[i]] = try r.bits(3) }
                    let codeLen = Huffman(lengths: lengths)
                    var all: [Int] = []
                    while all.count < nlen + ndist {
                        let sym = try r.decode(codeLen)
                        if sym < 16 { all.append(sym) } else {
                            var prev = 0, rep = 0
                            if sym == 16 {
                                guard let p = all.last else { throw Failure(reason: "repeat with no previous length") }
                                prev = p; rep = 3 + (try r.bits(2))
                            } else if sym == 17 { rep = 3 + (try r.bits(3)) } else { rep = 11 + (try r.bits(7)) }
                            all.append(contentsOf: [Int](repeating: prev, count: rep))
                        }
                    }
                    guard all.count == nlen + ndist else { throw Failure(reason: "too many code lengths") }
                    lenCode = Huffman(lengths: Array(all[0..<nlen]))
                    distCode = Huffman(lengths: Array(all[nlen...]))
                }
                while true {
                    let sym = try r.decode(lenCode)
                    if sym < 256 {
                        guard out.count < limit else { throw Failure(reason: "output exceeds the size limit") }
                        out.append(UInt8(sym))
                    } else if sym == 256 {
                        break
                    } else {
                        let li = sym - 257
                        guard li < 29 else { throw Failure(reason: "bad length symbol") }
                        let len = lengthBase[li] + (try r.bits(lengthExtra[li]))
                        let di = try r.decode(distCode)
                        guard di < 30 else { throw Failure(reason: "bad distance symbol") }
                        let dist = distBase[di] + (try r.bits(distExtra[di]))
                        guard dist <= out.count, out.count + len <= limit else { throw Failure(reason: "bad back-reference") }
                        let start = out.count - dist
                        for i in 0..<len { out.append(out[start + i]) }
                    }
                }
            default:
                throw Failure(reason: "bad block type")
            }
        }
        return out
    }
}

/// Reads the entries of a ZIP archive, with limits against oversized or hostile files.
enum ZipArchive {
    struct Entry { let name: String; let data: [UInt8] }

    static func u16(_ b: [UInt8], _ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
    static func u32(_ b: [UInt8], _ o: Int) -> Int { u16(b, o) | u16(b, o + 2) << 16 }

    static func entries(_ bytes: [UInt8], maxEntries: Int, maxTotalBytes: Int) throws -> [Entry] {
        guard bytes.count >= 22 else { throw Inflate.Failure(reason: "not a ZIP archive") }
        var eocd = -1
        var i = bytes.count - 22
        let stop = max(0, bytes.count - 22 - 65_535)
        while i >= stop {
            if bytes[i] == 0x50, bytes[i + 1] == 0x4b, bytes[i + 2] == 0x05, bytes[i + 3] == 0x06 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw Inflate.Failure(reason: "ZIP directory not found") }
        let count = u16(bytes, eocd + 10)
        var offset = u32(bytes, eocd + 16)
        guard count <= maxEntries else { throw Inflate.Failure(reason: "archive has too many entries") }
        var result: [Entry] = []
        var total = 0
        for _ in 0..<count {
            guard offset + 46 <= bytes.count, u32(bytes, offset) == 0x02014b50 else { throw Inflate.Failure(reason: "bad ZIP directory entry") }
            let method = u16(bytes, offset + 10)
            let compressed = u32(bytes, offset + 20)
            let uncompressed = u32(bytes, offset + 24)
            let nameLen = u16(bytes, offset + 28), extraLen = u16(bytes, offset + 30), commentLen = u16(bytes, offset + 32)
            let local = u32(bytes, offset + 42)
            guard offset + 46 + nameLen <= bytes.count else { throw Inflate.Failure(reason: "bad ZIP entry name") }
            let name = String(decoding: bytes[(offset + 46)..<(offset + 46 + nameLen)], as: UTF8.self)
            offset += 46 + nameLen + extraLen + commentLen
            if name.hasSuffix("/") { continue }
            guard !name.contains(".."), !name.hasPrefix("/"), !name.contains("\\") else { throw Inflate.Failure(reason: "unsafe path in archive") }
            total += uncompressed
            guard total <= maxTotalBytes else { throw Inflate.Failure(reason: "archive expands beyond the size limit") }
            guard local + 30 <= bytes.count, u32(bytes, local) == 0x04034b50 else { throw Inflate.Failure(reason: "bad ZIP local header") }
            let dataStart = local + 30 + u16(bytes, local + 26) + u16(bytes, local + 28)
            guard dataStart + compressed <= bytes.count else { throw Inflate.Failure(reason: "truncated ZIP entry") }
            let raw = Array(bytes[dataStart..<(dataStart + compressed)])
            switch method {
            case 0: result.append(Entry(name: name, data: raw))
            case 8:
                let data = try Inflate.decompress(raw, limit: maxTotalBytes)
                guard data.count == uncompressed else { throw Inflate.Failure(reason: "ZIP entry size mismatch") }
                result.append(Entry(name: name, data: data))
            default: throw Inflate.Failure(reason: "unsupported ZIP compression method \(method)")
            }
        }
        return result
    }
}
