# import pip

# def import_or_install(package):
#     try:
#         __import__(package)
#     except ImportError:
#         pip.main(['install', package])    
# import_or_install ("clang")
from clang.cindex import Index  
from clang.cindex import Config  
from clang.cindex import CursorKind  
from clang.cindex import TypeKind  
import json
import argparse

def getASTTree(sourceFileLoc,args):
    libclangPath = r'C:\Program Files\LLVM\bin\libclang.dll'
    Config.set_library_file(libclangPath)
    index = Index.create()
    tu = index.parse(sourceFileLoc,args=args)
    __rootNode=tu.cursor
    return __rootNode

parser=argparse.ArgumentParser("Command line interface")
parser.add_argument("-Command",type=str,dest="Command")
parser.add_argument("-OutputFile",type=str,dest="OutputFile")
parser.add_argument("-SourceFile",type=str,dest="SourceFile")
parser.add_argument("argv",nargs=argparse.REMAINDER,type=str)
parser.add_argument("-OutLoc", action='store_const', const=True)
# result=parser.parse_args(["-Command","hello","-SourceFile","1.c","asfasa","Fsdfsdfsfd","fsdfsdfsdf","-fgd321312312","ffsd"])
known,unknown=parser.parse_known_args()
if known.OutLoc is not None :
    print("hello")
astTree=getASTTree(known.SourceFile,unknown)
astTree.get_children()
container={}
def parseContainer(ast,container,depth=0):
    container["id"]=ast.hash
    container["name"]=ast.spelling
    container["displayName"]=ast.displayname
    container["kind"]=ast.kind.name 
    container["location"]=ast.location.file.name if ast.location.file else ""
    container["line"]=ast.location.line
    container["col"]=ast.location.column
    container["storage"]=ast.storage_class.name 
    container["reference"]=ast.referenced.hash if ast.referenced else -1
    # container["type"]=""
    
    for child in ast.get_children():
        if "inner" not in container:
            container["inner"]=[]        
        container["inner"].append({})
        parseContainer(child,container["inner"][-1],depth+1)
parseContainer(astTree,container)
with (open(known.OutputFile,'w') as outfile):
    outfile.write(json.dumps(container))

