// IUsbClockService.aidl
package com.chessnut.chessnutnext.clock;

import com.chessnut.chessnutnext.clock.IUsbClockListener;

/**
 * USB 棋钟控制接口（跨进程）。
 *
 * 第三方 app 通过显式 Intent 绑定此服务（action:
 * "com.chessnut.chessnutnext.clock.UsbClockService"，应用 package:
 * "com.chessnut.newchessnut"），即可读取按钮事件和发送控制命令。
 *
 * 设备由本 broker 进程独占持有，多个 app 可同时绑定共享。
 */
interface IUsbClockService {
    /**
     * 注册事件监听器，接收按钮事件和连接状态变化。
     */
    void registerListener(IUsbClockListener listener);

    /**
     * 注销事件监听器。
     */
    void unregisterListener(IUsbClockListener listener);

    /**
     * 获取当前连接状态。
     * @return 0 = DISCONNECTED, 1 = CONNECTING, 2 = CONNECTED
     */
    int getConnectionState();

    /**
     * 设置激活侧（控制棋钟 LED/指示）。
     * @param side 0 = LEFT, 1 = RIGHT
     * @return 命令是否发送成功
     */
    boolean setActiveSide(int side);

    /**
     * 获取设备最后一次上报的物理激活侧。
     * setActiveSide() 不会影响此值；连接后尚未收到有效上报或设备断开时为 UNKNOWN。
     * @return 0 = LEFT, 1 = RIGHT, -1 = UNKNOWN
     */
    int getActiveSide();
}
