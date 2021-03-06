//Model in extended version - with noise and bias and possible use of strengh
//////////////////////////////////////////////////////////////////////////////////////////
//Control parameters for the model
float RatioA=0.3; //How many "reds" in the array
float RatioB=0; //How many individualist in the array
float Noise=1; //some noise as a ratio of -MaxStrengh..MaxStrengh
float Bias=0;  //BIAS not implemented properly (work to strong currently!)

int   N=50;       //array side
float MaxStrengh=1000;//have not to be 0 or negative!
int   Distribution=0;//-5;//-6;//1 and -1 means flat, 0 means no difference, negative are Pareto, positive is Gaussian

//for flow and speed control of the program
int StepCounter=0;//!!!
int STOPAfter=1000;

int M=1;          //How often we draw visualization and calculate statistics
int Frames=100;    //How many frames per sec. we would like(!) to call.
boolean Running=true;

//for visualization
int S=10;       //cell width & height
int StatusHeigh=15; //For status line below cells
boolean UseLogDraw=false; //On/off of logarithic visualisation
boolean DumpScreens=false;//On/off of frame dumping

//For controling program from keyboard
boolean ready=true;//help for do one step at a time

//Statistics
int  Ones=0;
int  Zeros=0;
int  ConfOnes=0;
int  NConfOnes=0;
int  ConfZeros=0;
int  NConfZeros=0;
int  Conformist=0;
int  Nonconformist=0;

float Stress=0;
float ConfStress=0;
float NConStress=0;

float Dynamics=0;//How many changes?
float ConfDynamics=0;
float NConDynamics=0;

Clustering ClStat;//Cluster finding "device"

PrintWriter output;//For writing statistics into disk drive

//2D "World" of individuals
int A[][] = new int[N][N];     //Attitudes
float P[][] = new float[N][N];  //Strengh or "power"
boolean B[][] = new boolean[N][N]; //Individualism

void setup() //Window and model initialization
{
  noLoop(); //setup may take a longof time
  //noSmooth(); //For fastest visualization
  //println(param(0)+" "+param(1)+" "+param(2));//"param()" does not work :-(
  
  textSize(StatusHeigh);
  size(N*S,N*S+StatusHeigh+StatusHeigh/2);
  
  ClStat= new Clustering(A);
  String LogName="Ind_"+CtrlParValuesStr("-")+".log";
  output = createWriter(LogName); // Create a new file in the sketch directory
  
  DoModelInitialisation();
 
  loop();
  frameRate(Frames); //maximize speed
}

void exit() //it is called whenever a window is closed. 
{
  noLoop();        //For to be sure...
  delay(100);      // it is possible to close window when draw() is still working!
  output.flush();  // Writes the remaining data to the file
  output.close();  // Finishes the file
  println("Thank You");
  super.exit(); //What library superclass have to do at exit
} 

void draw() //Running - visualization, statistics and model dynamics
{
  if(StepCounter%M==0 || !Running ) //Do it every M-th step 
  {
    background(128); //Clear the window
    if(UseLogDraw)
        DoDrawSizeLog();
    else
        DoDrawFill();
    DoStatistics();
    if(DumpScreens) 
        saveFrame("frame-######.png");
  }
  
  if(keyPressed)
  {
    if(ready)
    {
     switch(key){
     case '8': ClStat.UseMoore=true; break;
     case '4': ClStat.UseMoore=false; break;  
     case 'B':            
     case 'b': ClStat.VisualBorders=!ClStat.VisualBorders;break;
     case 'C':            
     case 'c': ClStat.VisualClust=! ClStat.VisualClust; break;
     case 'D':
     case 'd': ClStat.VisualDiameters=!ClStat.VisualDiameters; break;
     case 'S':
     case 's': Running=false; break;
     case 'R': 
     case 'r': Running=true; break;
     }
     ready=false;
    } 
  }
  else ready=true;
 
  if(Running) 
    DoMonteCarloStep();
  
  if(Running && STOPAfter<StepCounter)
        Running=false;
}

float RandomGaussPareto(int Dist)// when Dist is negative, it is Pareto, when positive, it is Gauss
{
  if(Dist>0)
  {
    float s=0;
    for(int i=0;i<Dist;i++)
      s+=random(0,1);
    return s/Dist;  
  }
  else
  {
    float s=1;
    for(int i=Dist;i<0;i++)
       s*=random(0,1);
    return s;
  }
}

//int   Distribution=1;//1 means flat
void DoStrenghInitialisation()
{
  for(int i=0;i<N;i++)
   for(int j=0;j<N;j++)
   {
     if(Distribution!=0)
       P[i][j]=1+RandomGaussPareto(Distribution)*(MaxStrengh-1);//Not below one !!!
       else
       P[i][j]=MaxStrengh;
   }
}

void DoModelInitialisation()
{
  for(int i=0;i<N;i++)
   for(int j=0;j<N;j++)
    if( random(0,1) < RatioA )
     A[i][j]=1;
    else
     A[i][j]=0;
     
  for(int i=0;i<N;i++)
   for(int j=0;j<N;j++)
    if( random(0,1) < RatioB )
    {
     B[i][j]=true;
     Nonconformist++;
    }
    else
    {
     B[i][j]=false;
     Conformist++;
    } 
    
   DoStrenghInitialisation(); 
}

void DoMonteCarloStep()
{
   Dynamics=0;//How many changes?
   ConfDynamics=0;
   NConDynamics=0;
   
   for(int a=0;a<N*N;a++) //as many times as number of cells 
   {
     int i=int(random(N));
     int j=int(random(N));
     
     float support=0;
     for(int m=i-1;m<=i+1;m++)
      for(int n=j-1;n<=j+1;n++)
      {
        int p=(m+N)%N;
        int r=(n+N)%N;
        if(A[p][r]==A[i][j])
           support+=P[p][r];
           else
           support-=P[p][r];
      }
      
     support+=Noise*random(-MaxStrengh,MaxStrengh);
     
     if(Bias!=0) //Do we wont "bias" to work?
      if(A[i][j]==1) //Chmm? Is it work properly?
       support+=Bias*MaxStrengh;
       else          //I afraid, it is not the same way :-( as in previous papers
       support-=Bias*MaxStrengh;
     
     if(B[i][j])
     {
      if(support>=0)
      {
      Dynamics++;
      NConDynamics++;
      if(A[i][j]==1) //make switch
       A[i][j]=0;
       else
       A[i][j]=1;
      }
     }
     else
     if(support<0)
      {
      Dynamics++;
      ConfDynamics++;
      if(A[i][j]==1)//switch
       A[i][j]=0;
       else
       A[i][j]=1;
      }    
   }
   
   Dynamics/=(N*N);
   NConDynamics/=Nonconformist;
   ConfDynamics/=Conformist;   
   StepCounter++; //Step done
}


void DoDrawFill() //Visualize the cells or agents
{
  for(int i=0;i<N;i++)
  {
   for(int j=0;j<N;j++)
   {
    if(A[i][j]==1)
      fill(255*P[i][j]/MaxStrengh,0,0);
    else
      fill(255*P[i][j]/MaxStrengh);
         
    rect(i*S,j*S,S,S);
    if(RatioB>0)
    {
     if(B[i][j])
       fill(0,255,0);
     else
       fill(0,0,255);
     ellipse(i*S+S/2,j*S+S/2,S/2,S/2);
    }
   }
 }  
}

float log10 (float x) // Calculates the base-10 logarithm of a number
{
  return (log(x) / log(10));
}

void DoDrawSizeLog() //Visualize the cells or agents
{
  float Max=log10(MaxStrengh);
  for(int i=0;i<N;i++)
  {
   for(int j=0;j<N;j++)
   {
    if(A[i][j]==1)
      fill(255*P[i][j],0,0);
    else
      fill(255*P[i][j]);
     
    if(B[i][j])
      stroke(0,255,0);
    else
      stroke(0,0,255);  
         
    int SofThis=int(S*(log10(P[i][j])/Max)+1);
    rect(i*S,j*S,SofThis,SofThis);
   }
 }  
}

void Count()
{
  Ones=0;
  Zeros=0;
  Stress=0;
  ConfOnes=0;
  NConfOnes=0;
  ConfZeros=0;
  NConfZeros=0;
  ConfStress=0;
  NConStress=0;
  
  for(int i=0;i<N;i++)
   for(int j=0;j<N;j++)
   {
    if(A[i][j]==1)
    {
      if(B[i][j])
          NConfOnes++;
      else
          ConfOnes++;
      Ones++;
    }
    else
    {
      if(B[i][j])
          NConfZeros++;
      else
          ConfZeros++;
      Zeros++;
    }
    
     int LStress=0;
     for(int m=i-1;m<=i+1;m++)
      for(int n=j-1;n<=j+1;n++)
      {
        int p=(m+N)%N;
        int r=(n+N)%N;
        if(A[p][r]!=A[i][j])
           LStress++;
      }  
      
      Stress+=LStress/8.0;  
      
      if(B[i][j])
          NConStress+=LStress/8.0;
          else
          ConfStress+=LStress/8.0;
   }
   
   Stress/=(N*N);
   NConStress/=Nonconformist;
   ConfStress/=Conformist;
}

void DoStatistics() //Calculate and print statistics,  into text file & maybe also to console
{ 
  if(StepCounter==0 && Running)// Write the headers to the file only once
     output.println("StepCounter\t Dynamics\t ConfDynamics\t NConDynamics\t  Zeros\t  Ones\t ConfZeros\t NConfZeros\t ConfOnes\t NConfOnesStress\t ConfStress\t NConStress\t frameRate"+"\t "
                   +ClStat.HeaderStr("\t ")+"\t "+CtrlParHeaderStr("\t ")); 

  Count(); //Calculate the after step statistics 
  
  ClStat.Calculate(); //Calculate quite complicate clusters statistics
  //ConfZeros,NConfZeros,ConfOnes,NConfOnes
  String  Stats=StepCounter+"\t "+Dynamics+"\t "+ConfDynamics+"\t "+NConDynamics+"\t "+Zeros+"\t "+Ones+"\t "+ConfZeros+"\t "+NConfZeros+"\t "+ConfOnes+"\t "+NConfOnes+"\t "+Stress+"\t "+ConfStress+"\t "+NConStress+"\t "+frameRate+"\t "
                  +ClStat.StatsStr("\t ")+"\t "+CtrlParValuesStr("\t ");
  fill(0,0,0);            //Color of text (!) on the window
  if(!DumpScreens) 
      text(Stats, 1,S*(N+1)+1);//Print the statistics on the window
  else
      text("Step:"+StepCounter+" Opinions: "+Zeros+" : "+Ones, 1,S*(N+1)+1);
      
  if(Running)
  {
  //  println(Stats);        // Write the statistics to the console
    output.println(Stats); // Write the statistics to the file
  }
}

String CtrlParHeaderStr(String Sep)
{
  return "RatioA"+Sep//=0.5; //How many "reds" in the array
  +"RatioB"+Sep//=0.99; //How many individualist in the array
  +"Noise"+Sep//=1.5; //some noise as a ratio of -MaxStrengh..MaxStrengh
  +"MaxStrengh"+Sep//=1000;//have not to be 0 or negative!
  +"Distribution"+Sep//=0;//-5;//-6;//1 and -1 means flat, 0 means no difference, negative are Pareto, positive is Gaussian
  +"N";//=50;       //array side
}

String CtrlParValuesStr(String Sep)
{
  return RatioA+Sep//=0.5; //How many "reds" in the array
  +RatioB+Sep//=0.99; //How many individualist in the array
  +Noise+Sep//=1.5; //some noise as a ratio of -MaxStrengh..MaxStrengh
  +MaxStrengh+Sep//=1000;//have not to be 0 or negative!
  +Distribution+Sep//=0;//-5;//-6;//1 and -1 means flat, 0 means no difference, negative are Pareto, positive is Gaussian
  +N;//=50;       //array side
}

//***********************************************************************
// 2013 (c) Wojciech Tomasz Borkowski  http://borkowski.iss.uw.edu.pl
//***********************************************************************
