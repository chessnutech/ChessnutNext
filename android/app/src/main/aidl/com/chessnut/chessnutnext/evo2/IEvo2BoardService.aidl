package com.chessnut.chessnutnext.evo2;

import com.chessnut.chessnutnext.evo2.IEvo2BoardListener;

/**
 * Cross-process EVO2 USB board broker.
 *
 * Bind with action "com.chessnut.chessnutnext.evo2.Evo2BoardService" and
 * package "com.chessnut.newchessnut".
 */
interface IEvo2BoardService {
    void registerListener(IEvo2BoardListener listener);
    void unregisterListener(IEvo2BoardListener listener);

    /** Returns the latest board-only FEN, or an empty string if unavailable. */
    String getLatestFen();
    byte[] getLatestFenPayload();

    /** Requests/enables real-time FEN reports from the board HID interface. */
    boolean requestFen();

    /** Eight row bitmasks, one byte per chessboard rank. */
    boolean setLedRows(in byte[] rows);

    /** 64 squares * 7 * 7 pixels * RGB888 bytes. */
    boolean setLedPatternPixels(in byte[] pixels);

    boolean clearLeds();

    /** Sends a raw EVO2 LED matrix command. */
    boolean writeLedCommand(in byte[] command);

    /** Sends a raw EVO2 board HID command. */
    boolean writeBoardCommand(in byte[] command);
}
