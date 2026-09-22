package com.chessnut.chessnutnext.evo2;

/** Cross-process EVO2 board event callback. */
oneway interface IEvo2BoardListener {
    /** 0 = DISCONNECTED, 1 = CONNECTING, 2 = CONNECTED. */
    void onConnectionStateChanged(int state);

    /** Called whenever the physical-board FEN changes. */
    void onFenChanged(String fen, in byte[] rawPayload);

    /** Raw non-FEN board response. */
    void onResponse(in byte[] payload);

    void onError(String error);
}
