beh_anno=csvread('manual_annotation.csv');
beh_anno(beh_anno(:,:)~=1)=0
rev_anno=diff(beh_anno)
run_length_rev=NaN(size(beh_anno))
for i=1:25
rev_start=[];rev_end=[];
rev_end=find(rev_anno(:,i)==-1);
rev_start=find(rev_anno(:,i)==1);
for k=1:length(rev_end)-1
run_length_rev(rev_end(k):rev_start(k+1),i)=[0:rev_start(k+1)-rev_end(k)];
end
run_length_rev(rev_end(k+1):end,i)=[0:length(beh_anno)-rev_end(k+1)];
end
csvwrite('time_from_rev.csv',run_length_rev)