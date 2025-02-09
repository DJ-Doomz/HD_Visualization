import java.util.*;
import java.io.*;
import com.hamoid.*;
import java.awt.*;

String[] monthNames = {"JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"};

int DAY_LEN;
int PEOPLE_COUNT;
String[] textFile;
Person[] people;
int TOP_VISIBLE = 10;
float[] maxes;
float[] mins;
int[] wrStreak;
String[] wrHolder;
int[] unitChoices;

float X_MIN = 100;
float X_MAX = 1900;
float Y_MIN = 300;
float Y_MAX = 1000;
float X_W = X_MAX-X_MIN;
float Y_H = Y_MAX-Y_MIN;
float BAR_PROPORTION = 0.9;
int START_DATE = dateToDays("2022-09-04");
int END_DATE = dateToDays("2024-09-23");
int ACTUAL_LENGTH = 750;
float TEXT_MARGIN = 8;

float currentScale = -1;
float currentMin = 300;

int frames = 0;
float currentDay = 0;
float FRAMES_PER_DAY = 5.6;
int START_DAY = 0;
float BAR_HEIGHT;
PFont font;

int[] unitPresets = {1,2,5,10,20,50,100,200,500,1000,2000,5000,10000,20000,50000,100000,200000,500000,1000000};
VideoExport videoExport;

void setup(){
  font = createFont("Tinos-Regular.ttf", 60);
  randomSeed(432766);
  textFile = loadStrings("leaderboard_history.csv");
  String[] parts = textFile[0].split(",");
  DAY_LEN = textFile.length-1;
  PEOPLE_COUNT = parts.length-2;
  
  maxes = new float[DAY_LEN];
  mins = new float[DAY_LEN];
  unitChoices = new int[DAY_LEN];
  wrStreak = new int[DAY_LEN];
  wrHolder = new String[DAY_LEN];
  for(int d = 0; d < DAY_LEN; d++){
    maxes[d] = 0;
    mins[d] = 0;
    wrStreak[d] = 0;
    wrHolder[d] = "";
  }
  
  people = new Person[PEOPLE_COUNT];
  for(int i = 0; i < PEOPLE_COUNT; i++){
    people[i] = new Person(parts[i+1]);
  }
  for(int d = 0; d < DAY_LEN; d++){
    String[] dataParts = textFile[d+1].split(",");
    for(int p = 0; p < PEOPLE_COUNT; p++){
      float val = Float.parseFloat(dataParts[p+1]);
      people[p].values[d] = val;
      // detect if they PB'd
      float EPSILON = .005;
      if(d > 1)
      {
        float previous_score = people[p].values[d-1];
        if(val > previous_score + EPSILON)
        {
          people[p].dvalues[d] = val - previous_score;
          people[p].days_since_pb[d] = 0;
        }
        else
        {
          people[p].dvalues[d] = people[p].dvalues[d-1];
          people[p].days_since_pb[d] = people[p].days_since_pb[d-1] + 1;
        }
      }

      if(val > maxes[d]){
        maxes[d] = val;
      }
    }
  }
  getRankings();
  getUnits();
  BAR_HEIGHT = (rankToY(1)-rankToY(0))*BAR_PROPORTION;
  size(1920,1080);
  
  videoExport = new VideoExport(this,"outputtedVideoFULL.mp4");
  videoExport.setFrameRate(60);
  videoExport.startMovie();
}


void draw(){
  currentDay = getDayFromFrameCount(frames);
  currentMin = getMin(currentDay);
  currentScale = getXScale(currentDay);
  drawBackground();
  drawHorizTickmarks();
  drawBars();
  drawWRStreak();
  drawFades();
  saveVideoFrameHamoid();
  frames++;
}
float alpha = 0;
void drawFades(){
  int fade_in_frames = 30;
  int fade_out_frames = 180;
  
  if(frames < fade_in_frames)
    alpha = 255. - 255. * frames/fade_in_frames;
  else if(currentDay < ACTUAL_LENGTH + 10)
    alpha = 0;
  else
    alpha += 255.0*(1.0/fade_out_frames);

  if(alpha > 0)
  {
    blendMode(SUBTRACT);       // we're subtracting colors now
    noStroke();                // no borders
    fill(255, alpha);             // subtract white with low alpha 
    rect(0, 0, width, height); // full window rectangle 
    blendMode(BLEND);          // reset blend mode to default
  }
}

float getMin(float d)
{
  return clamp(WAIndex(mins,d,14) - 10, 0, 420);
}

public static float clamp(float val, float min, float max) {
    return Math.max(min, Math.min(max, val));
}

void saveImage(){
  saveFrame("tutorialImages/img"+frames+".png");
}

void saveVideoFrameHamoid(){
  videoExport.saveFrame();
  /*
  if(getDayFromFrameCount(frames+1) >= DAY_LEN){ 
    videoExport.endMovie();
    exit();
  }
  */
}

float getDayFromFrameCount(int fc){
  return clamp(fc/FRAMES_PER_DAY+START_DAY, 0, DAY_LEN-1);
}

void drawWRStreak()
{
  //in upper left
  int fontsize = 40;
  float x = X_MIN;
  float y = fontsize + 20;
  textFont(font, fontsize);
  fill(255);
  text("Current WR Holder:", x, y);
  y += fontsize;
  text(wrHolder[(int)currentDay], x, y);
  y += fontsize;
  textFont(font, 30);
  text("Streak: " + wrStreak[(int)currentDay] + " days", x, y);
}

void drawBackground(){
  background(0);
  fill(255);
  textFont(font,110);
  textAlign(RIGHT);
  text(daysToDate(clamp(currentDay, 0, ACTUAL_LENGTH),true),width-40,150);
  fill(100);
  textAlign(CENTER);
  textFont(font,62);
  text("HD Top 10",840,Y_MIN-100);
}

void drawHorizTickmarks(){
  float preferredUnit = WAIndex(unitChoices, currentDay, 4);
  float unitRem = preferredUnit%1.0;
  if(unitRem < 0.001){
    unitRem = 0;
  }else if(unitRem >= 0.999){
    unitRem = 0;
    preferredUnit = ceil(preferredUnit);
  }
  int thisUnit = unitPresets[(int)preferredUnit];
  int nextUnit = unitPresets[(int)preferredUnit+1];
  
  drawTickMarksOfUnit(thisUnit,255-unitRem*255);
  if(unitRem >= 0.001){
    drawTickMarksOfUnit(nextUnit,unitRem*255);
  }
  // permanent line at X_MIN?
  fill(50,50,50,255);
  rect(X_MIN,Y_MIN-20,4,Y_H+20);
}

int clampToUnit(int v, int u)
{
  int rem = v%u;
  return v - rem;
}

void drawTickMarksOfUnit(int u, float alpha){
  for(int v = clampToUnit((int)currentMin, u); v < currentMin + currentScale*1.4; v+=u){
    float x = valueToX(v);
    // decrease alpha if x goes too far left
    float amod = clamp(x, 0, X_MIN + 40)/(X_MIN+40);
    fill(100,100,100,alpha*amod);
    float W = 4;
    rect(x-W/2,Y_MIN-20,W,Y_H+20);
    textAlign(CENTER);
    textFont(font,62);
    text(keyify(v),x,Y_MIN-30);
  }
}

void drawBars(){
  noStroke();
  for(int p = 0; p < PEOPLE_COUNT; p++){
    Person pe = people[p];
    if(pe.ranks[(int)currentDay] > 11)
      continue;
    float val = linIndex(pe.values,currentDay);
    val = clamp(val, currentMin, 999);
    float x = valueToX(val);
    float rank = WAIndex(pe.ranks, currentDay, 4.3);
    float y = rankToY(rank);
    fill(pe.c);
    rect(X_MIN,y,x-X_MIN,BAR_HEIGHT);
    fill(255);
    textFont(font,55);
    textAlign(RIGHT);
    float appX = max(x-TEXT_MARGIN,X_MIN+textWidth(pe.name)+TEXT_MARGIN*2);
    text(pe.name,appX,y+BAR_HEIGHT-15);
    textFont(font,40);
    fill(180);
    textAlign(LEFT);
    String cscore = String.format("%.3f", val);
    text(cscore, appX+15, y+BAR_HEIGHT-10);
    // draw PB amts, fading out after a few days
    float alpha = clamp(255-25*linIndex(pe.days_since_pb,currentDay), 0, 255);
    appX += textWidth(cscore) + 15;
    textFont(font, 28);
    fill(0, 150, 255, alpha);
    String pb = "+" + String.format("%.3f", pe.dvalues[(int)currentDay]);
    text(pb, appX + 10, y+BAR_HEIGHT-20);
  }
}

void getRankings(){
  for(int d = 0; d < DAY_LEN; d++){
    boolean[] taken = new boolean[PEOPLE_COUNT];
    for(int p = 0; p < PEOPLE_COUNT; p++){
      taken[p] = false;
    }
    for(int spot = 0; spot < TOP_VISIBLE; spot++){
      float record = -1;
      int holder = -1;
      for(int p = 0; p < PEOPLE_COUNT; p++){
        if(!taken[p]){
          float val = people[p].values[d];
          if(val > record){
            record = val;
            holder = p;
          }
        }
      }
      people[holder].ranks[d] = spot;
      //keep track of WR holder
      if(d > 0)
      {
        if(spot == 0)
        {
          if(wrHolder[d-1] == people[holder].name && d < ACTUAL_LENGTH) // streak continues
          {
            wrStreak[d] = wrStreak[d-1] + 1;
            wrHolder[d] = wrHolder[d-1];
          }
          else  // new WR holder
          {
            wrStreak[d] = 1;
            wrHolder[d] = people[holder].name;
          }
        }
      }
      if(spot == 9)
      {
        mins[d] = people[holder].values[d];
      }
      taken[holder] = true;
    }
  }
}
float stepIndex(float[] a, float index){
  return a[(int)index];
}
float linIndex(float[] a, float index){
  int indexInt = (int)index;
  float indexRem = index%1.0;
  float beforeVal = a[indexInt];
  float afterVal = a[min(DAY_LEN-1,indexInt+1)];
  return lerp(beforeVal,afterVal,indexRem);
}
float WAIndex(float[] a, float index, float WINDOW_WIDTH){
  int startIndex = max(0,ceil(index-WINDOW_WIDTH));
  int endIndex = min(DAY_LEN-1,floor(index+WINDOW_WIDTH));
  float counter = 0;
  float summer = 0;
  for(int d = startIndex; d <= endIndex; d++){
    float val = a[d];
    float weight = 0.5+0.5*cos((d-index)/WINDOW_WIDTH*PI);
    counter += weight;
    summer += val*weight;
  }
  float finalResult = summer/counter;
  return finalResult;
}
float WAIndex(int[] a, float index, float WINDOW_WIDTH){
  float[] aFloat = new float[a.length];
  for(int i = 0; i < a.length; i++){
    aFloat[i] = a[i];
  }
  return WAIndex(aFloat,index,WINDOW_WIDTH);
}

float getXScale(float d){
  return (WAIndex(maxes,d,14) - currentMin)*1.2;
}
float valueToX(float val){
  return X_MIN+X_W*(val-currentMin)/currentScale;
}
float rankToY(float rank){
  float y = Y_MIN+rank*(Y_H/TOP_VISIBLE);
  return y;
}
String daysToDate(float daysF, boolean longForm){
  int days = (int)daysF+START_DATE+1;
  Date d1 = new Date();
  d1.setTime(days*86400000l);
  int year = d1.getYear()+1900;
  int month = d1.getMonth()+1;
  int date = d1.getDate();
  if(longForm){
    return year+" "+monthNames[month-1]+" "+date;
  }else{
    return year+"-"+nf(month,2,0)+"-"+nf(date,2,0);
  }
}
int dateToDays(String s){
  int year = Integer.parseInt(s.substring(0,4))-1900;
  int month = Integer.parseInt(s.substring(5,7))-1;
  int date = Integer.parseInt(s.substring(8,10));
  Date d1 = new Date(year, month, date, 6, 6, 6);
  int days = (int)(d1.getTime()/86400000L);
  return days;
}
void getUnits(){
  
  for(int d = 0; d < DAY_LEN; d++){
    currentMin = getMin(d);
    float Xscale = getXScale(d);  //Xscale is more like the current range
    for(int u = 1; u < unitPresets.length; u++){
      if(unitPresets[u] >= Xscale/3.0){ // That unit was too large for that scaling!
        unitChoices[d] = u-1; // Fidn the largest unit that WASN'T too large (i.e., the last one.)
        break;
      }
    }
  }
  

  //for(int d = 0; d < DAY_LEN; d++){
  //  unitChoices[d] = 4; // Fidn the largest unit that WASN'T too large (i.e., the last one.)
  //}

}
String keyify(int n){
  if(n < 1000){
    return n+"";
  }else if(n < 1000000){
    if(n%1000 == 0){
      return (n/1000)+"K";
    }else{
      return nf(n/1000f,0,1)+"K";
    }
  }
  if(n%1000000 == 0){
    return (n/1000000)+"M";
  }else{
    return nf(n/1000000f,0,1)+"M";
  }
}
