//
//  Shader.fsh
//  MagicGlasses3
//
//  Created by Roman Smirnov on 19.11.12.
//  Copyright (c) 2012 Roman Smirnov. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
