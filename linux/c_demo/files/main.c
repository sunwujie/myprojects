#include <stdio.h>
#include <stdlib.h>

int main()
{
	long dev;
	long offset;
	long length;
	char ch;
	double ts=0.000000;
	FILE * fp;

	if((fp = fopen("program.txt","r"))<0)
	{
		printf("open the file is error!\n");
		exit(0);
	}

	while(5==fscanf(fp,"%ld,%ld,%ld,%c,%lf\n",&dev,&offset,&length,&ch,&ts))
	{
		printf("%ld,%ld,%ld,%c,%lf\n",dev,offset,length,ch,ts);
	}
	fclose(fp);
	return 0;
}
