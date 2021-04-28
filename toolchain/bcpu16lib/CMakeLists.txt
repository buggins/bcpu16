project(bcpu16lib)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

SET (BCPU16LIB_SOURCES 
    src/cmdline.cpp  
    src/sourcefile.cpp  
    src/tokenizer.cpp  
)

ADD_LIBRARY(bcpu16lib STATIC ${BCPU16LIB_SOURCES})
