package com.chessnut.chessnutnext

internal object Evo2FenCodec {
    private val pieces = charArrayOf(
        '0', 'q', 'k', 'b', 'p', 'n', 'R', 'P',
        'r', 'B', 'N', 'Q', 'K'
    )

    fun tryDecode(data: ByteArray): String? {
        return try {
            decode(data)
        } catch (_: Throwable) {
            null
        }
    }

    private fun decode(data: ByteArray): String {
        val payloadOffset = when {
            data.size >= 34 -> 2
            data.size == 33 -> 1
            data.size == 32 -> 0
            else -> throw IllegalArgumentException("EVO2 FEN payload is too short")
        }
        return buildString {
            for (rank in 0 until 8) {
                if (rank > 0) append('/')
                var empty = 0
                for (file in 7 downTo 0) {
                    val boardIndex = rank * 8 + file
                    val value = data[boardIndex / 2 + payloadOffset].toInt() and 0xff
                    val encoded = if (file % 2 == 0) value and 0x0f else value ushr 4
                    val piece = pieces.getOrElse(encoded) { '0' }
                    if (piece == '0') {
                        empty += 1
                    } else {
                        if (empty > 0) {
                            append(empty)
                            empty = 0
                        }
                        append(piece)
                    }
                }
                if (empty > 0) append(empty)
            }
        }
    }
}
