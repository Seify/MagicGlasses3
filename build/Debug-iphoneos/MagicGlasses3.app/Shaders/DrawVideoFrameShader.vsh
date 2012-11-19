

uniform mat4 modelViewProjectionMatrix;

attribute mediump vec3 position;
attribute mediump vec2 texCoords;

varying mediump vec2 fTexCoords;

void main()
{ 
    fTexCoords = texCoords;
    
    vec4 postmp = vec4(position.xyz, 1.0);
    gl_Position = modelViewProjectionMatrix * postmp;
}
