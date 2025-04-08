uniform vec2 lightPosition;
uniform float lightAngle;
uniform float lightWidth;
uniform float lightRange;
uniform float ambientLight;
uniform bool inShack;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Get the original color
    vec4 pixel = Texel(texture, texture_coords) * color;
    
    // If player is in shack, only use ambient light
    if (inShack) {
        return pixel * vec4(ambientLight, ambientLight, ambientLight, 1.0);
    }
    
    // Calculate direction from light to pixel
    vec2 lightDir = screen_coords - lightPosition;
    float distance = length(lightDir);
    
    // Normalize direction
    lightDir = normalize(lightDir);
    
    // Calculate light direction vector based on angle
    vec2 lightFacing = vec2(cos(lightAngle), sin(lightAngle));
    
    // Calculate angle between light facing and pixel direction
    float cosAngle = dot(lightFacing, lightDir);
    
    // Cone angle calculation (1.0 means straight ahead, -1.0 means behind)
    float coneInfluence = pow(max(0.0, cosAngle), lightWidth);
    
    // Distance attenuation
    float attenuation = max(0.0, 1.0 - distance / lightRange);
    
    // Total light influence
    float lightInfluence = coneInfluence * attenuation;
    
    // Add ambient light
    lightInfluence = min(1.0, lightInfluence + ambientLight);
    
    // Apply lighting with a yellow tint (more red and green, less blue)
    // CHANGE THESE VALUES AND "ambientLight" TO TWEAK LIGHTING
    return pixel * vec4(lightInfluence * 0.8, lightInfluence * 0.7, lightInfluence * 0.6, 1.0);
}
