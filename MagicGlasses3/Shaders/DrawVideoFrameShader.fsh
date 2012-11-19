//
//  Shader.fsh
//  OpenGL Test
//
//  Created by Roman Smirnov on 09.10.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

precision lowp float;

uniform sampler2D texture;

varying mediump vec2 fTexCoords;

void main()
{
    vec4 color = texture2D(texture, fTexCoords);
    gl_FragColor = color.bgra;
//    gl_FragColor = vec4(0.5, 0.0, 0.0, 0.5);
}
