#include<iostream>
#include<list>
#include<vector>
#include<fstream>
#include <filesystem>

using namespace std;
namespace fs = std::filesystem;

void parse(ifstream& fin, int index)
{
    fs::create_directories("./split/p" + to_string(index));
    ofstream fout("./split/p"+to_string(index)+"/reg_trace.dat");
    string line;
    while(fin.peek() == '\n')
    {
        fin.ignore();
    }
    while(fin>>line)
    {
        
        if(line[0] == 'P')
        {
            getline(fin,line);
            break;
        }
        fout<<line<<endl;
    }
}

int main()
{
    ifstream fin("REG_SHOULD_BE.txt");
    for(int i = 0 ; i < 200 ; i++)
    {
        parse(fin,i);
    }
}