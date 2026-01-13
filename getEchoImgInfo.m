function [imgInfo, PixelSize, selectDepth] = getEchoImgInfo(img, ax)
%  GETECHOIMGINFO この関数の簡単な概要です。
% 画像の横幅に対する中央の画像を切り出し、その中の画素が存在する範囲からエコー画像のタテのpixel数を推定
% エコー画像の深度と画像のタテpizel数からpixelSizeを算出する
% input
% img: image
% ax: ROIを選択するためのimshowに続いてこのfunctionを使用するので、ROI選択のときのimageのaxを受け取る
% output
% imgInfo: 自動認識したエコー画像のある上下左右端の座標
% PixelSize: 自動認識orユーザーがマニュアルで選択したスケールから計算した1pixelのサイズ[mm]
% selectDepth: 手動で選択した実測の長さ[mm]→本当に正しく認識できるいるかimageで確認するときに使う
% 読み込んだ画像が3次元(RGB)であれば2次元化する
Ndim = ndims(img);
if Ndim == 3
    img = img(:,:,1);
end
%% 0) 上下の画像情報などの帯を削除する。例えばi700の上端の帯
% 元画像を別変数名に. double = 二値化の意味
imgDouble = img;
% 閾値以下の画素は0に
imgDouble(imgDouble ~= 0) = 1;
% 各行で画素の存在する割合を算出
RowRatio = sum(imgDouble, 2)/size(imgDouble,2);
% 一定以上の割合の場合、エコー画像でなく、
FilledRowIdx = RowRatio > 0.98; % 0.98は任意
% ±2 の範囲をカバーするカーネル（長さ5のウィンドウ）
kernel = ones(5,1);
% 帯がある部分の±2の範囲も0に置き換え
FilledRowIdx = conv(double(FilledRowIdx), kernel, 'same') > 0;
% 帯部分には0を代入
img(FilledRowIdx, :) = 0;
%% 1) エコー画像の存在する上端(Up)の自動認識 ------------------------------------------
% 上端を決めるための画像を一旦作成
imgUp = img;
% uint8形式で一定値以上の値の画素を1にする. エコー画像の近隣では、視認できないような薄い画素が混在しているのでそれを消す目的
% 閾値の設定
ther = max(imgUp,[],"all")/30; % 30は任意
% 閾値以下の画素は0に
imgUp(imgUp < ther) = 0;
imgUp(imgUp > ther) = 1;
% ヨコ方向に画素の存在するpixel数を加算
sumRowUp = sum(imgUp, 2);
% ヨコ方向のpixel数に対して、1/2以上の画素があればエコー画像ありの行と判断し、そのindexを取得
sizeWidth = size(imgUp, 2);
indexExistRow = sumRowUp>(sizeWidth/3); %[注意本来1/2で行ったが縦長の画像に対して対応できなかったため、1/3にする]
indexNonExistRow = sumRowUp<(sizeWidth/3);
% 上記のエコー画像ありの行は1を、なければ0へ
sumRowUp(indexExistRow,:) = 1;
sumRowUp(indexNonExistRow,:) = 0;
% ★エコー画像が存在する最初の行がエコーの上端
imgInfo.Up = find(sumRowUp, 1); % ,1は最初に0以外の値が出現するときのindexを取得する
%% 2 ) エコー画像の存在する下端(Bottom)の自動認識 ------------------------------------------
% 上端を決めるための画像を一旦作成
imgBottom = img;
% 画素のあるpixelを1に
imgBottom(imgBottom ~= 0) = 1;
% 画素のあるpixelを「ヨコ」方向に加算　→　エコー画像のある部分の「行」は値が高くなるはず
% 左右の画像をcutする。左右の画像情報をエコー画像と誤認しないように
% cutする幅
cutW = round(size(imgBottom,2)/8); % 8は任意
% 左右をcutした画像
imgBottom = img(:,cutW:end-cutW);
% ここで0が格納された行は画素が存在しない‼
sumRowBottom = sum(imgBottom, 2);
% ヨコ方向のpixel数に対して、1/2以上の画素があればエコー画像ありの行と判断し、そのindexを取得
indexExistRow = sumRowBottom>(sizeWidth/2); 
indexNonExistRow = sumRowBottom<(sizeWidth/2);
% 上記のエコー画像ありの行は1を、なければ0へ
sumRowBottom(indexExistRow,:) = 1;
sumRowBottom(indexNonExistRow,:) = 0;
% 連続するデータをカウントアップする関数(cf. https://jp.mathworks.com/matlabcentral/answers/834918-)
countupRow = cell2mat(arrayfun(@(t)1:t,diff(find([1 diff(sumRowBottom') 1])),'un',0));
% 上記yのピーク値とインデックスを取得
[~, countupMaxIdxRow] = max(countupRow);
% ★最も長く連続した数値の最後のindexがエコーの下端を示す
imgInfo.Bottom = countupMaxIdxRow;
%% 3) エコー画像の存在する左右端(left, right)の自動認識 ------------------------------------------
% タテ方向に画素の存在するpixel数を加算
sumCol = sum(img, 1); 
% タテ方向のpixel数に対して、1/2以上の画素があればエコー画像ありの列と判断し、そのindexを取得
sizeHeight = size(img,2);
indexExistCol = sumCol>(sizeHeight/2);
indexNonExistCol = sumCol<(sizeHeight/2);
% 上記のエコー画像ありの列は1を、なければ0へ
sumCol(:,indexExistCol) = 1;
sumCol(:,indexNonExistCol) = 0;
% 連続するデータをカウントアップする関数(cf. https://jp.mathworks.com/matlabcentral/answers/834918-)
countupCol = cell2mat(arrayfun(@(t)1:t,diff(find([1 diff(sumCol) 1])),'un',0));
[countupMaxCol, countupMaxIdxCol] = max(countupCol);
% ★最も長く連続した数値の最後のindexがエコーの右端を示す
imgInfo.Right = countupMaxIdxCol;
% ★最も長く連続した数値の始めの値がエコーの左端を示す
imgInfo.Left = countupMaxIdxCol - countupMaxCol + 1; % +1しないと黒の最終点になるため追加
%% 第２段階：エコー画像の1pixelのサイズを自動計算 ------------------------------------------
% 選択肢作成
selectList = {'5mm','10mm','15mm','20mm','25mm','30mm','35mm','40mm','45mm','50mm','55mm','60mm','65mm','70mm','Manual'};
% ダイアログボックス
[indx, ~] = listdlg('PromptString',{'最も深い深度の目盛り値を選択',''},...
    'SelectionMode','single','ListString',selectList, 'ListSize', [190, 170],'Name', 'Set Scale'); % 深度を指定するか、手動で設定するかの選択
% エコーの深度
depthList = [5,10,15,20,25,30,35,40,45,50,55,60,65,70];
%% "Manual"を選択した場合
if strcmp(selectList{indx}, 'Manual') == 1
    %% ROIを設定するようにメッセージを表示
    % 画面中央に表示するために現在の座標軸を取得
    centerX = round(ax.XLim(2)*0.5); % 左右は画面中央に    
    centerY = round(ax.YLim(2)*0.9); % 上下は下から0.1のところに
    % 背景ボックス
    rectangle('Position', [centerX-250, centerY-30, 600, 60], ...
        'FaceColor', [0 0 0], 'EdgeColor', 'none');  % 黒い背景
    % text表示
    TEXT1 = text(centerX, centerY, '深度0の高さを右クリック', 'Color', [0.86 0.08 0.24], 'FontSize', 25, 'HorizontalAlignment', 'center'); 
    % 目視にてscaleとなる長さをクリック、座標を取得
    [scaleX1, scaleY1, ~] = impixel; % 座標を取得
    % クリックした点を赤丸で表示
    hold on;
    hs1 = plot(scaleX1(end), scaleY1(end), 'ro', 'MarkerSize', 12, 'LineWidth', 2); hold off;
    delete(TEXT1)
 
    % text表示
    TEXT2 = text(centerX, centerY, '最も深いスケールの高さを右クリック', 'Color', [0.86 0.08 0.24], 'FontSize', 25, 'HorizontalAlignment', 'center');
    % 目視にてscaleとなる長さをクリック、座標を取得
    [scaleX2, scaleY2, ~] = impixel; % 座標を取得
    % クリックした点を赤丸で表示
    hold on;
    hs2 = plot(scaleX2(end), scaleY2(end), 'ro', 'MarkerSize', 12, 'LineWidth', 2);
    delete(TEXT2)
    % xy軸それぞれの最大距離を算出→深度scaleだけでなく、横のscaleに使うこともあるため
    x = abs(scaleX1(end) - scaleX2(end));
    y = abs(scaleY1(end) - scaleY2(end));
    
    % 左右方向の差が大きいのであれば、左右のscaleを認識したと判断
    if x > y
        PixelNum = x;
    elseif y > x % 上下方向の差が大きいのであれば、上下（深度）のscaleを認識したと判断
        PixelNum = y;
    end
    [indxDepth,~] = listdlg('PromptString',{'赤丸間の距離を選択',''},...
        'SelectionMode','single','ListString',selectList(1:end-1));
    % 実測(選択した)の深度
    selectDepth = depthList(indxDepth);
    % 実測深度をピクセル数で割ることで、1pixelあたりの長さを取得
    PixelSize = selectDepth/PixelNum; % [mm]
    % manualを選択したということはエコー画像範囲認識に問題があったと推測されるので、エコー範囲はユーザーがマニュアルでクリックした座標にする
    imgInfo.Up = scaleY1(end); % この座標に「エコー自動認識確認」の黄色バーが引かれる
    imgInfo.Bottom = scaleY2(end);
    % manualで実施する画像解析には深度の選択部位は渡さないので赤丸を削除
    delete(hs1)
    delete(hs2)
%% 自動でscaleを計算
else % selectListから実測長さが選ばれているので、以下のコードでpixel数を計算する
    % 実測(選択した)の深度
    selectDepth = depthList(indx);
    % エコー画像の存在するPixel数
    PixelNum = imgInfo.Bottom - imgInfo.Up;
    
    % 実測の深度をPixel数で除すことで1pixelのサイズ[mm]を取得
    PixelSize = selectDepth./PixelNum;
end
% 読み込み画像が黒抜けしている場合には、正しく計算されない
% 0.1以上となったら警告を出す
if PixelSize > 0.1
    warning('PixelSizeが正しく計算されていない可能性あり。画像の下端が黒抜けしていませんか？')
end
end
%% old
% この関数の簡単な概要です。
% 
% この関数の詳細な説明です。
% function [imgInfo, PixelSize, selectDepth] = getEchoImgInfo(img)
% % 画像の横幅に対する中央の画像を切り出し、その中の画素が存在する範囲からエコー画像のタテのpixel数を推定
% % エコー画像の深度と画像のタテpizel数からpixelSizeを算出する
% % 「realDepth」：手動で選択した実測の長さ[mm]→本当に正しく認識できるいるかimageで確認するときに使う
% 
% % 読み込んだ画像が3次元(RGB)であれば2次元化する
% Ndim = ndims(img);
% 
% if Ndim == 3
%     img = img(:,:,1);
% end
% 
% %% 第１段階：画像の内、エコー画像の存在する範囲の自動認識 ------------------------------------------
% 
% % 画素のあるpixelを1に
% img(img ~= 0) = 1;
% %% 画素のあるpixelを「ヨコ」方向に加算　→　エコー画像のある部分の「行」は値が高くなるはず
% % 左右の画像をcutする。左右の画像情報をエコー画像と誤認しないように
% % cutする幅
% cutW = round(size(img,2)/8); % 8は任意
% % 左右をcutした画像
% imgRow = img(:,cutW:end-cutW);
% % ここで0が格納された行は画素が存在しない‼
% echoRow = sum(imgRow, 2);
% 
% %% 画素のあるpixelを「タテ」方向に加算　→　エコー画像のある部分の「列」は値が高くなるはず
% % 上下の画像をcutする。i700などは上下に帯状に画像情報があるため、それをエコー画像と誤認しないように
% % cutする高さ
% cutH = round(size(img,1)/4); % 8は任意
% % 上下をcutした画像
% imgCol = img(cutH:end-cutH,:);
% % ここで0が格納された列は画素が存在しない‼
% echoCol = sum(imgCol, 1); 
% % エコー画像が存在する列には全て画素があるため、その値を格納
% echoPixelRow = max(echoRow);
% echoPixelCol = max(echoCol);
% 
% % 行列データのうち、一定以上の画素が存在するindexを取得
% % row = 画像の上下方向
% indexExistRow = echoRow>(echoPixelRow/5); % /2であれば、全pixel数に対して、1/10以上の画素があればエコー画像ありの行と判断
% indexNonExistRow = echoRow<(echoPixelRow/5);
% % col = 画像の左右方向
% indexExistCol = echoCol>(echoPixelCol/5);
% indexNonExistCol = echoCol<(echoPixelCol/5);
% 
% % 画素が画像の横幅に対して半数以上あれば1を、なければ0へ
% % row = 画像の上下方向
% echoRow(indexExistRow,:) = 1;
% echoRow(indexNonExistRow,:) = 0;
% % col = 画像の左右方向
% echoCol(:,indexExistCol) = 1;
% echoCol(:,indexNonExistCol) = 0;
% 
% % 連続するデータをカウントアップする関数(cf. https://jp.mathworks.com/matlabcentral/answers/834918-)
% yRow = cell2mat(arrayfun(@(t)1:t,diff(find([1 diff(echoRow') 1])),'un',0));
% yCol = cell2mat(arrayfun(@(t)1:t,diff(find([1 diff(echoCol) 1])),'un',0));
% % 上記yのピーク値とインデックスを取得
% [yMaxRow, yMaxIdxRow] = max(yRow);
% [yMaxCol, yMaxIdxCol] = max(yCol);
% 
% % 最も長く連続した数値の最後のindexがエコーの下端を示す
% imgInfo.Bottom = yMaxIdxRow;
% % 最も長く連続した数値の始めの値がエコーの上端を示す
% imgInfo.Up = yMaxIdxRow - yMaxRow + 1; % +1しないと黒の最終点になるため追加
% % 最も長く連続した数値の最後のindexがエコーの右端を示す
% imgInfo.Right = yMaxIdxCol;
% % 最も長く連続した数値の始めの値がエコーの左端を示す
% imgInfo.Left = yMaxIdxCol - yMaxCol + 1; % +1しないと黒の最終点になるため追加
% 
% %% 第２段階：エコー画像の1pixelのサイズを自動計算 ------------------------------------------
% % 選択肢作成
% selectList = {'15mm','20mm','25mm','30mm','35mm','40mm','45mm','50mm','Manual'};
% % ダイアログボックス
% [indx,~] = listdlg('PromptString',{'最も深い深度の目盛り値を選択',''},...
%     'SelectionMode','single','ListString',selectList, 'ListSize', [160, 170]); % 深度を指定するか、手動で設定するかの選択
% 
% % エコーの深度
% depthList = [15,20,25,30,35,40,45,50];
% 
% % 実測(選択した)の深度
% selectDepth = depthList(indx);
% 
% %% "Manual"を選択した場合
% if strcmp(selectList{indx}, 'Manual') == 1
%     % 目視にてscaleとなる長さをクリック、座標を取得
%     [scaleX,scaleY,~] = impixel(img); 
%     % xy軸それぞれの最大距離を算出→深度scaleだけでなく、横のscaleに使うこともあるため
%     x = abs(scaleX(1) - scaleX(2));
%     y = abs(scaleY(1) - scaleY(2));
% 
%     % 左右方向の差が大きいのであれば、左右のscaleを認識したと判断
%     if x > y
%         PixelNum = x;
%     elseif y > x % 上下方向の差が大きいのであれば、上下（深度）のscaleを認識したと判断
%         PixelNum = y;
%     end
% 
%     [indxDepth,~] = listdlg('PromptString',{'Select a depth.',''},...
%     'SelectionMode','single','ListString',selectList{1:end-1});
% 
%     % 実測深度をピクセル数で割ることで、1pixelあたりの長さを取得
%     PixelSize = selectDepth(indxDepth)/PixelNum; % [mm]
% 
% %% 自動でscaleを計算
% else % selectListから実測長さが選ばれているので、以下のコードでpixel数を計算する
%     % エコー画像の存在するPixel数
%     PixelNum = imgInfo.Bottom - imgInfo.Up;
% 
%     % 実測の深度をPixel数で除すことで1pixelのサイズ[mm]を取得
%     PixelSize = selectDepth/PixelNum;
% end
% 
% % 読み込み画像が黒抜けしている場合には、正しく計算されない
% % 0.1以上となったら警告を出す
% if PixelSize > 0.1
%     warning('PixelSizeが正しく計算されていない可能性あり。画像の下端が黒抜けしていませんか？')
% end
% 
% end
% 
% 
%