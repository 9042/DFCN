clc ;close all;clear all
patchSizeData=155;
centerLabelPatchSize=32*4;
pad=200;% for each image

numBlockFromEachImageMain=700;
imageAddress='./Dataset/Original/';


percentBorder=0.30;
percentInner=0.40;
percentOutter=0.40;

numFileInDir=[31 31 32 32];
for foldNum=1:4
    n=0;
    foldNum
    
%%% ------------------sort file--------------------------------------------
    dirData = dir([imageAddress 'Fold' num2str(foldNum) '/']);  
    dirIndex = [dirData.isdir];
    fileList = {dirData(~dirIndex).name}';  %'# Get a list of the files 
    file=cell(1,numFileInDir(foldNum));
    index=1;
    for i=1:numel(fileList)
        fileName=fileList{i};
        fileName = strsplit(fileName,'.');
        if(strcmp(fileName(end),'png'))
            continue
        end
        fileName=fileList{i};        
        fileName = strsplit(fileName,'orig');        
        file{index}=fileName{1};
        index=index+1;
       
    end
  
    for numSubDataset=1:2
        if (numSubDataset==1)
            subName='Train';
            numFile=size(file,2)-9;
            
        else
            subName='Test'
            numFile=9;            
        end
        
         totalSampel=round(numFile*numBlockFromEachImageMain);   
       %--create dataset Train
         finalPatch=zeros(patchSizeData,patchSizeData,3,totalSampel);
         finalLabel=zeros(centerLabelPatchSize,centerLabelPatchSize,1,totalSampel);
         finalWeight=zeros(centerLabelPatchSize,centerLabelPatchSize,1,totalSampel);
         

        nFinalData=1;   
        
        address='./Dataset/';
        system(['rm ' address 'DataBaseFold' num2str(foldNum) subName '.h5']);
        h5create([address 'DataBaseFold' num2str(foldNum) subName '.h5'],'/GlobalPatch',[patchSizeData patchSizeData 3 totalSampel],'Datatype','single');
        h5create([address 'DataBaseFold' num2str(foldNum) subName '.h5'],'/LabelPatch',[centerLabelPatchSize centerLabelPatchSize 1 totalSampel],'Datatype','single');
        h5create([address 'DataBaseFold' num2str(foldNum) subName '.h5'],'/Weight',[centerLabelPatchSize centerLabelPatchSize 1 totalSampel],'Datatype','single');




%%% -----------------------------------------------------------------------

    %% ----------- 
        while(n<numFileInDir(foldNum))
            n=n+1
            if(n>(numFileInDir(foldNum)-9) && numSubDataset==1)
                n=n-1;
                break;
            end
            nFinalData
            for degree=0:30:290
                

                fileName=[file{1,n}];
                numBlockFromEachImage=numBlockFromEachImageMain;

                 
                orgI=imread([imageAddress 'Fold' num2str(foldNum) '/' fileName 'orig.jpg']);
                %orgI=imresize(orgI,0.5);


                orgI=double(orgI);
                temp=[];
                temp(:,:)=orgI(:,:,1);
                temp=(temp-mean(temp(:)))/std(temp(:));
                orgI(:,:,1)=temp;

                temp(:,:)=orgI(:,:,2);
                temp=(temp-mean(temp(:)))/std(temp(:));
                orgI(:,:,2)=temp;

                temp(:,:)=orgI(:,:,3);
                temp=(temp-mean(temp(:)))/std(temp(:));
                orgI(:,:,3)=temp;
                
                

                [Yorg ,Xorg,~]=size(orgI);
                orgI=padarray(orgI,[10*pad/2 10*pad/2], 'symmetric');        
                orgI=single(orgI);
                orgI=imrotate(orgI,degree,'crop');
                centerY=floor(size(orgI,1)/2);
                centerX=floor(size(orgI,2)/2);
                Yorg=Xorg/2+pad+10;% becase for crop max(y,x) is important
                Xorg=Xorg/2+pad+10;
                orgI=orgI(centerY-Yorg+1:centerY+Yorg,centerX-Xorg+1:centerX+Xorg,:);        
                
           
                %%---------read mask and select are in mask
                mask=imread([imageAddress 'Fold' num2str(foldNum) '/' fileName  'contour.png']);
                mask=imresize(mask,0.5);
                mask(mask>0)=1;
                
                weightMatrix=ComputeDistancFromBordereWeight(mask);  
                
                
                border=zeros(size(mask));
                border=padarray(border,[10*pad/2 10*pad/2],1); 
                SE=ones(floor(centerLabelPatchSize/2));
                border=imdilate(border,SE);% for force big win located in inside dilated image
                border=imrotate(border,degree,'crop');
                border=border(centerY-Yorg+1:centerY+Yorg,centerX-Xorg+1:centerX+Xorg,:); 
                
                
                mask=padarray(mask,[10*pad/2 10*pad/2]);
                mask=imrotate(mask,degree,'crop');
                mask=mask(centerY-Yorg+1:centerY+Yorg,centerX-Xorg+1:centerX+Xorg,:);  

            weightMatrix=padarray(weightMatrix,[10*pad/2 10*pad/2]);                       
            weightMatrix=imrotate(weightMatrix,degree,'crop');
            weightMatrix=weightMatrix(centerY-Yorg+1:centerY+Yorg,centerX-Xorg+1:centerX+Xorg,:);  
            weightMatrix(find(weightMatrix==0))=1; 
                
                                   
            selectedArea=zeros(size(mask));
            SE=ones(3);
            borderMask=imdilate(mask,SE)-mask;
            SE=ones(20);
            borderMask=imdilate(borderMask,SE);

            remindDot=numBlockFromEachImage/10;            
            indexBorder=find(borderMask==1 & border==0);
            index=randperm(numel(indexBorder));
            totDotBorder=floor(min(numBlockFromEachImage*percentBorder/10,numel(indexBorder)));
            borderIndex=indexBorder(index(1:totDotBorder));
            selectedArea(borderIndex)=1;
            remindDot=remindDot-totDotBorder;

            indexInner=find(borderMask==0 & mask==1 & border==0);
            index=randperm(numel(indexInner));
            totDotInner=floor(min(numBlockFromEachImage*percentInner/10,numel(indexInner)));
            innerIndex=indexInner(index(1:totDotInner));
            selectedArea(innerIndex)=1;            
            remindDot=remindDot-totDotInner;

            indexOutter=find(borderMask==0 & mask==0 & border==0);
            index=randperm(numel(indexOutter));
            totDotOutter=remindDot;
            outterIndex=indexOutter(index(1:ceil(totDotOutter)));
            selectedArea(outterIndex)=1;            

            [indexY ,indexX]=find(selectedArea==1);
            tempIndex=randperm(numel(indexY));
            indexY=indexY(tempIndex);
            indexX=indexX(tempIndex);           
        
                PSD=floor(patchSizeData/2);
                CPS=floor(centerLabelPatchSize/2);


                i=0;
                insertedPatch=0;
                while(insertedPatch<numBlockFromEachImage/10)
                     i=i+1;
                     temp=mask(indexY(i)-CPS+1:indexY(i)+CPS,indexX(i)-CPS+1:indexX(i)+CPS);
                     temp3=weightMatrix(indexY(i)-CPS+1:indexY(i)+CPS,indexX(i)-CPS+1:indexX(i)+CPS);
                     insertedPatch=insertedPatch+1;
                     temp2=orgI(indexY(i)-PSD:indexY(i)+PSD,indexX(i)-PSD:indexX(i)+PSD,:);
                     
                     randNum=rand;
                     if(randNum>0.5)
                         temp2=flip(temp2,1);
                         temp3=flip(temp3,1);
                         temp=flip(temp,1);
                     end
                     randNum=rand;                     
                     if(randNum>0.5)
                         temp2=flip(temp2,2);
                         temp3=flip(temp3,2);
                         temp=flip(temp,2);
                     end     

                     finalLabel(:,:,:,nFinalData)=single(temp);
                     finalWeight(:,:,:,nFinalData)=single(temp3);                     
                     finalPatch(:,:,:,nFinalData)=temp2;                     
                     nFinalData=nFinalData+1; 
                end      
            end
        end

        nFinalData=nFinalData-1;
        if(nFinalData~=size(finalLabel,4))
            disp('Error in generating dataset');
            input(prompt)
        end
        index=randperm(nFinalData);
        finalLabel=finalLabel(:,:,:,index);
        finalPatch=finalPatch(:,:,:,index);
        finalWeight=finalWeight(:,:,:,index);


        finalPatch=single(finalPatch);
        finalLabel=single(finalLabel);
        finalWeight=single(finalWeight);
        disp('darsad')
        sum(finalLabel(:))/numel(finalLabel)

        

        h5write([address 'DataBaseFold' num2str(foldNum) subName '.h5'], '/GlobalPatch',finalPatch,[1 1 1 1],[patchSizeData patchSizeData 3 totalSampel]);
        h5write([address 'DataBaseFold' num2str(foldNum) subName '.h5'], '/LabelPatch',finalLabel,[1 1 1 1],[centerLabelPatchSize centerLabelPatchSize 1 totalSampel]);
        h5write([address 'DataBaseFold' num2str(foldNum) subName '.h5'], '/Weight',finalWeight,[1 1 1 1],[centerLabelPatchSize centerLabelPatchSize 1 totalSampel]);
    end

    
end
