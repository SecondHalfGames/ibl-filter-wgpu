# ibl-filter-wgpu
This is a dump of the shaders from our environment map filtering code. It generates cubemaps for image-based lighting (IBL) in real time from a dynamic environment.

This uses the technique described in this [placeholderart.wordpress.com blog post](https://placeholderart.wordpress.com/2015/07/28/implementation-notes-runtime-environment-map-filtering-for-image-based-lighting/) which is itself based on the Unreal and Frostbite papers it links.

The input environment map should have a full mip chain generated for it beforehand, as it's used for both the specular and diffuse techniques.

The specular filtering code uses the filtered importance sampling with variable sample count described in the blog post.

The diffuse filtering code uses uniform sampling on a lower mip level to generate smoother results. I couldn't find any examples of other folks doing this, but I'd be surprised if I was the first.