// IUsbClockListener.aidl
package com.chessnut.chessnutnext.clock;

/**
 * USB 棋钟事件回调接口（跨进程）。
 *
 * 第三方 app 实现此接口并通过 IUsbClockService.registerListener 注册，
 * 即可接收按钮事件和连接状态变化。
 */
oneway interface IUsbClockListener {
    /**
     * 连接状态变化。
     * @param state 0 = DISCONNECTED, 1 = CONNECTING, 2 = CONNECTED
     */
    void onConnectionStateChanged(int state);

    /**
     * 激活侧变化事件。设备协议没有独立的按下/释放状态。
     * @param side      0 = LEFT, 1 = RIGHT
     * @param timestamp 事件时间戳（毫秒）
     */
    void onButtonEvent(int side, long timestamp);

    /**
     * 错误回调。
     */
    void onError(String error);
}
