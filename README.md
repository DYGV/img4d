# PNG decoder   
## これはなに  
**PNGファイルの構造を知りたくなってD言語の勉強がてら作ってみたやつ(必須チャンクのみ)**  
逆フィルタリングは未実装  
(ツッコミどころ満載のコードだと思われます)  
## ToDo  
- 逆フィルタリング処理  
- DIBオブジェクト作成  
- ウィンドウに画像表示  
## 現状  (NoneとSubフィルターだけを適応)   
![tri](https://user-images.githubusercontent.com/8480644/44565390-d54e0200-a7a2-11e8-9e86-145ce42987fc.png)  
↑ なんとなく三角形だがなぜか二値化されたようになっている  
  
![lena](https://user-images.githubusercontent.com/8480644/44565484-4beaff80-a7a3-11e8-98f4-7abe6a0707b0.png)  
↑ 帽子がなんとなく表現されているのがわかるだけ



