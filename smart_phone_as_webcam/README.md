### 概要

[scrcpy](https://github.com/genymobile/scrcpy)を使って、スマホをウェブカメラとして利用する。

```sh
sudo apt install v4l2loopback-dkms -y # 仮想Webカメラデバイス（ダミーのビデオ入力）を作成するためのカーネルモジュール
sudo ln -s  ~/Downloads/scrcpy-linux-x86_64-v5.0.1/adb /usr/local/bin/adb # シンボリックリンクの作成 (適宜ディレクトリ名を修正
sudo ln -s  ~/Downloads/scrcpy-linux-x86_64-v5.0.1/scrcpy /usr/local/bin/scrcpy # シンボリックリンクの作成 (適宜ディレクトリ名を修正
```

```sh
sudo modprobe v4l2loopback video_nr=20 card_label="scrcpy-webcam" exclusive_caps=1
ll /dev/video* # 確認
# ここでandroidの開発者モードをONにして、USBデバックモードをONにします。
adb devices # ADB接続状態の確認 出力結果に端末のシリアル番号と device と表示されれば認識成功

# 設定は適宜変更すること
scrcpy --video-source=camera \
  --v4l2-sink=/dev/video20 \
  --no-playback \
  --no-control \
  --no-audio \
  --camera-size=1024x576 \
  --camera-fps=15 \
  --video-bit-rate=2M \
  --video-codec=h264

ffplay -f v4l2 /dev/video20 # 動作確認

# --camera-size=1024x576 --camera-fps=15 等の使用可能な設定は要確認
scrcpy --video-source=camera --list-camera-sizes
```

再起動すれば消えます

```sh
sudo modprobe -r v4l2loopback # 即座にモジュールアンロード
```

### スクリプト化

以下、個人用スクリプトをまとめておきます。

`~/.bash_aliases`とかに記載

```sh
export PATH="$HOME/.local/bin:$PATH"
```
